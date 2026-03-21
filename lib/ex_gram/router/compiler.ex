defmodule ExGram.Router.Compiler do
  @moduledoc """
  `@before_compile` hook that generates the `handle/2` function from the
  routing tree built by the DSL macros.

  This module is used internally by `ExGram.Router` and should not be
  referenced directly.

  ## What gets generated

  Given this router definition:

      use ExGram.Router

      scope do
        filter :command, :start
        handle &MyBot.start/1
      end

      scope do
        handle &MyBot.fallback/1
      end

  The compiler generates:

      def handle(update_info, context) do
        ExGram.Router.Dispatcher.dispatch(update_info, context, __exgram_routing_tree__())
      end

      def __exgram_routing_tree__ do
        [
          %ExGram.Router.Scope{
            filters: [{ExGram.Router.Filters.Command, :start}],
            children: [],
            handler: {MyBot, :start, 1}
          },
          %ExGram.Router.Scope{
            filters: [],
            children: [],
            handler: {MyBot, :fallback, 1}
          }
        ]
      end
  """

  defmacro __before_compile__(env) do
    scopes = Module.get_attribute(env.module, :__exgram_scopes__) |> Enum.reverse()
    stack = Module.get_attribute(env.module, :__exgram_scope_stack__)

    if stack != [] do
      raise CompileError,
        file: env.file,
        description:
          "ExGram.Router: scope stack is not empty at end of module. " <>
            "This is an internal error — please report it."
    end

    # Remove the default `handle/2` injected by `use ExGram.Bot` so our
    # generated clause wins.  `defoverridable` alone is not sufficient because
    # the default clause was defined earlier in the module body and Elixir
    # matches clauses top-to-bottom.
    Module.delete_definition(env.module, {:handle, 2})

    quote do
      @doc false
      def __exgram_routing_tree__ do
        unquote(Macro.escape(scopes))
      end

      @doc false
      def handle(update_info, context) do
        ExGram.Router.Dispatcher.dispatch(update_info, context, __exgram_routing_tree__())
      end
    end
  end
end
