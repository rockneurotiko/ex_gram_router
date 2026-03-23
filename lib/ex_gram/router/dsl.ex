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

  @stack_attribute :__exgram_scope_stack__
  @aliases_attribute :__exgram_filter_aliases__

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
      current_stack = ExGram.Router.Dsl.__get_stack(__MODULE__)

      ExGram.Router.Dsl.__put_stack(__MODULE__, [%ExGram.Router.Scope{} | current_stack])

      # Expand the block contents (may add filters, handlers, nested scopes)
      unquote(block)

      # Pop the completed scope
      {completed, rest_stack} =
        ExGram.Router.Dsl.__get_current_stack!(__MODULE__, "scope",
          description: "empty scopes are not allowed; a scope must have filters, a handle, or nested scopes"
        )

      # Validate the completed scope
      ExGram.Router.Dsl.__validate_scope__!(completed, __MODULE__)

      case rest_stack do
        [] ->
          # Top-level scope: register it in @__exgram_scopes__
          # We prepend, so @before_compile must reverse to get declaration order
          Module.put_attribute(__MODULE__, :__exgram_scopes__, completed)
          ExGram.Router.Dsl.__put_stack(__MODULE__, [])

        [parent | rest] ->
          # Nested scope: add as child of the parent scope
          updated_parent = %{parent | children: parent.children ++ [completed]}
          ExGram.Router.Dsl.__put_stack(__MODULE__, [updated_parent | rest])
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
      {current, rest} = ExGram.Router.Dsl.__get_current_stack!(__MODULE__, "filter/2")

      filter_module =
        ExGram.Router.Dsl.__resolve_filter_module__!(
          __MODULE__,
          unquote(module_or_alias),
          __ENV__
        )

      updated = %{current | filters: current.filters ++ [{filter_module, unquote(opts)}]}
      ExGram.Router.Dsl.__put_stack(__MODULE__, [updated | rest])
    end
  end

  @doc """
  Sets the handler for the current scope.

  Accepts a function capture of arity 1 or 2, or an anonymous function:
  - Arity 1: `&MyMod.fun/1`, `&my_local_fun/1`, or `fn context -> ... end` - receives only the context
  - Arity 2: `&MyMod.fun/2`, `&my_local_fun/2`, or `fn update_info, context -> ... end` - receives
    `(update_info, context)`, same as ExGram's `handle/2`

  Local captures (`&my_fun/1`) support both public (`def`) and private (`defp`) functions.

  ## Examples

      handle &MyBot.start/1
      handle &MyBot.handle_text/2
      handle &my_local_handler/1

      handle fn context ->
        context |> answer("Hello!")
      end

      handle fn update_info, context ->
        context
      end
  """
  defmacro handle(func) do
    # Parse the handler AST at compile time, before emitting any runtime code.
    handler = __parse_handler__!(func, __CALLER__)

    # For anonymous functions the handler is the fn AST itself wrapped in an
    # {:unquote, [], [...]} marker so that Macro.escape/2 with unquote: true
    # splices it as compiled code rather than trying to serialize the function.
    # We escape the marker tuple itself so it is stored as plain data in the
    # scope struct (module attribute), not evaluated as an unquote expression.
    handler_ast =
      case handler do
        {:fn, fn_ast} -> Macro.escape({:unquote, [], [fn_ast]})
        mfa -> Macro.escape(mfa)
      end

    quote do
      {current, rest} = ExGram.Router.Dsl.__get_current_stack!(__MODULE__, "handle/1")

      if current.handler != nil do
        raise CompileError,
          file: __ENV__.file,
          line: __ENV__.line,
          description: "a scope can only have one handle/1 call"
      end

      updated = %{current | handler: unquote(handler_ast)}
      ExGram.Router.Dsl.__put_stack(__MODULE__, [updated | rest])
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
      current_aliases = ExGram.Router.Dsl.__get_aliases(__MODULE__)

      if Keyword.has_key?(current_aliases, unquote(alias_atom)) do
        raise CompileError,
          file: __ENV__.file,
          line: __ENV__.line,
          description: "filter alias #{inspect(unquote(alias_atom))} is already defined in this module"
      end

      ExGram.Router.Dsl.__put_aliases(__MODULE__, [{unquote(alias_atom), unquote(module)} | current_aliases])
    end
  end

  # ---------------------------------------------------------------------------
  # Internal helpers (public so they can be called from macro-generated code)
  # ---------------------------------------------------------------------------

  def __get_aliases(module) do
    Module.get_attribute(module, @aliases_attribute)
  end

  def __put_aliases(module, aliases) do
    Module.put_attribute(module, @aliases_attribute, aliases)
  end

  @doc false
  def __get_stack(module) do
    Module.get_attribute(module, @stack_attribute)
  end

  def __put_stack(module, stack) do
    Module.put_attribute(module, @stack_attribute, stack)
  end

  @doc false
  def __get_current_stack!(module, method, opts \\ []) do
    stack = __get_stack(module)

    if stack == [] do
      description = opts[:description] || "#{method} must be called inside a scope block"

      raise CompileError,
        file: __ENV__.file,
        line: __ENV__.line,
        description: description
    end

    [current | rest] = stack

    {current, rest}
  end

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
      aliases = __get_aliases(module)

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

      # &my_local_fun/N  (local function capture, no module prefix)
      # Treated like an anonymous fn - compiled as a function value so that
      # private functions (defp) are also supported.
      {:&, _, [{:/, _, [{fun_name, _, _}, arity]}]} when is_atom(fun_name) and is_integer(arity) ->
        if arity not in [1, 2] do
          raise CompileError,
            file: env.file,
            line: env.line,
            description: "handle/1 expects a function capture of arity 1 or 2, got arity #{arity}"
        end

        {:fn, func}

      # fn args -> body end  (anonymous function, one or more clauses)
      {:fn, _, [{:->, _, [first_args, _body]} | _rest_clauses]} ->
        arity = length(first_args)

        if arity not in [1, 2] do
          raise CompileError,
            file: env.file,
            line: env.line,
            description: "handle/1 expects a function of arity 1 or 2, got arity #{arity}"
        end

        {:fn, func}

      _ ->
        raise CompileError,
          file: env.file,
          line: env.line,
          description:
            "handle/1 expects a function capture like &MyMod.fun/1, &my_local_fun/1, or &MyMod.fun/2, " <>
              "or an anonymous function like fn context -> ... end, " <>
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
