defmodule ExGram.Router.Dsl do
  @moduledoc """
  Compile-time DSL macros for building the routing tree.

  These macros are imported automatically when you `use ExGram.Router`.
  You should not need to import this module directly.

  ## How the scope stack works

  During compilation, a module attribute `@__exgram_scope_stack__` acts as a
  stack of "in-progress" scopes. When `scope do ... end` is entered, a new
  empty scope is pushed. The block body runs (adding filters, handlers, or
  nested scopes). When the block ends, the completed scope is popped and
  either attached to the parent scope (as a child) or registered as a
  top-level scope.

  The final list of top-level scopes is stored in `@__exgram_scopes__` and
  consumed by `ExGram.Router.Compiler` in the `@before_compile` hook.
  """

  @doc """
  Opens a new routing scope. A scope can contain:
  - `filter` declarations (zero or more)
  - `handle` (exactly one, for leaf scopes)
  - Nested `scope` blocks (for branch scopes)

  A scope must have either a `handle` OR nested `scope` blocks, not both.
  """
  defmacro scope(do: block) do
    quote do
      # Push a new empty scope onto the stack
      current_stack = Module.get_attribute(__MODULE__, :__exgram_scope_stack__)

      Module.put_attribute(
        __MODULE__,
        :__exgram_scope_stack__,
        [%ExGram.Router.Scope{} | current_stack]
      )

      # Expand the block contents (may add filters, handlers, nested scopes)
      unquote(block)

      # Pop the completed scope
      [completed | rest_stack] = Module.get_attribute(__MODULE__, :__exgram_scope_stack__)

      # Validate the completed scope
      ExGram.Router.Dsl.__validate_scope__!(completed, __MODULE__)

      case rest_stack do
        [] ->
          # Top-level scope: register it in @__exgram_scopes__
          # We prepend, so @before_compile must reverse to get declaration order
          Module.put_attribute(__MODULE__, :__exgram_scopes__, completed)
          Module.put_attribute(__MODULE__, :__exgram_scope_stack__, [])

        [parent | rest] ->
          # Nested scope: add as child of the parent scope
          updated_parent = %{parent | children: parent.children ++ [completed]}
          Module.put_attribute(__MODULE__, :__exgram_scope_stack__, [updated_parent | rest])
      end
    end
  end

  @doc """
  Adds a filter to the current scope.

  ## Atom alias form (recommended)

      filter :command, :start
      filter :text

  ## Module form

      filter MyApp.Filters.AdminOnly
      filter MyApp.Filters.State, :registration

  The atom alias must have been registered via `alias_filter/2`.
  """
  defmacro filter(module_or_alias, opts \\ nil) do
    quote do
      stack = Module.get_attribute(__MODULE__, :__exgram_scope_stack__)

      if stack == [] do
        raise CompileError,
          file: __ENV__.file,
          line: __ENV__.line,
          description: "filter/1-2 must be called inside a scope block"
      end

      filter_module =
        ExGram.Router.Dsl.__resolve_filter_module__!(
          __MODULE__,
          unquote(module_or_alias),
          __ENV__
        )

      [current | rest] = stack
      updated = %{current | filters: current.filters ++ [{filter_module, unquote(opts)}]}
      Module.put_attribute(__MODULE__, :__exgram_scope_stack__, [updated | rest])
    end
  end

  @doc """
  Sets the handler for the current scope.

  Accepts a function capture of arity 1 or 2:
  - Arity 1: `&MyMod.fun/1` — receives only the context
  - Arity 2: `&MyMod.fun/2` — receives `(update_info, context)`, same as ExGram's `handle/2`

  ## Examples

      handle &MyBot.start/1
      handle &MyBot.handle_text/2
  """
  defmacro handle(func) do
    # Parse the handler AST at compile time, before emitting any runtime code.
    handler = __parse_handler__!(func, __CALLER__)

    quote do
      stack = Module.get_attribute(__MODULE__, :__exgram_scope_stack__)

      if stack == [] do
        raise CompileError,
          file: __ENV__.file,
          line: __ENV__.line,
          description: "handle/1 must be called inside a scope block"
      end

      [current | rest] = stack

      if current.handler != nil do
        raise CompileError,
          file: __ENV__.file,
          line: __ENV__.line,
          description: "a scope can only have one handle/1 call"
      end

      updated = %{current | handler: unquote(Macro.escape(handler))}
      Module.put_attribute(__MODULE__, :__exgram_scope_stack__, [updated | rest])
    end
  end

  @doc """
  Registers a short atom alias for a filter module.

  ## Example

      alias_filter ExGram.Router.Filters.Command, as: :command
      alias_filter ExGram.Router.Filters.Text, as: :text
      alias_filter MyApp.Filters.State, as: :state

  After this, you can use the alias in `filter` calls:

      filter :command, :start
      filter :state, :registration
  """
  defmacro alias_filter(module, as: alias_atom) when is_atom(alias_atom) do
    quote do
      current_aliases = Module.get_attribute(__MODULE__, :__exgram_filter_aliases__)

      if Keyword.has_key?(current_aliases, unquote(alias_atom)) do
        raise CompileError,
          file: __ENV__.file,
          line: __ENV__.line,
          description: "filter alias #{inspect(unquote(alias_atom))} is already defined in this module"
      end

      Module.put_attribute(
        __MODULE__,
        :__exgram_filter_aliases__,
        [{unquote(alias_atom), unquote(module)} | current_aliases]
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Internal helpers (public so they can be called from macro-generated code)
  # ---------------------------------------------------------------------------

  @doc false
  def __resolve_filter_module__!(module, alias_or_module, env) when is_atom(alias_or_module) do
    # Check if it looks like a module (starts with uppercase when stringified)
    # or an alias (lowercase atom like :command)
    alias_str = Atom.to_string(alias_or_module)

    if String.starts_with?(alias_str, Elixir |> Atom.to_string()) or
         String.match?(alias_str, ~r/^[A-Z]/) do
      # It's a module reference passed as atom — use as-is
      alias_or_module
    else
      # It's an alias atom like :command — look it up
      aliases = Module.get_attribute(module, :__exgram_filter_aliases__)

      case Keyword.fetch(aliases, alias_or_module) do
        {:ok, resolved_module} ->
          resolved_module

        :error ->
          raise CompileError,
            file: env.file,
            line: env.line,
            description:
              "unknown filter alias #{inspect(alias_or_module)}. " <>
                "Register it with: alias_filter SomeModule, as: #{inspect(alias_or_module)}"
      end
    end
  end

  @doc false
  def __parse_handler__!(func, env) do
    case func do
      # &SomeModule.fun/N  (the fun call AST has a trailing [] for args)
      {:&, _, [{:/, _, [{{:., _, [mod_ast, fun]}, _, []}, arity]}]} when is_integer(arity) ->
        mod = Macro.expand(mod_ast, env)

        if arity not in [1, 2] do
          raise CompileError,
            file: env.file,
            line: env.line,
            description: "handle/1 expects a function capture of arity 1 or 2, got arity #{arity}"
        end

        {mod, fun, arity}

      _ ->
        raise CompileError,
          file: env.file,
          line: env.line,
          description:
            "handle/1 expects a function capture like &MyMod.fun/1 or &MyMod.fun/2, " <>
              "got: #{Macro.to_string(func)}"
    end
  end

  @doc false
  def __validate_scope__!(scope, _module) do
    has_handler = scope.handler != nil
    has_children = scope.children != []

    cond do
      has_handler and has_children ->
        raise CompileError,
          description:
            "a scope cannot have both a handle/1 and nested scope blocks. " <>
              "Use a branch scope (filters + children) or a leaf scope (filters + handle), not both."

      not has_handler and not has_children ->
        raise CompileError,
          description:
            "a scope must have either a handle/1 or nested scope blocks. " <>
              "Empty scopes are not allowed."

      true ->
        :ok
    end
  end
end
