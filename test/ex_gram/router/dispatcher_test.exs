defmodule ExGram.Router.DispatcherTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Dispatcher
  alias ExGram.Router.Scope

  # Minimal context mock - Dispatcher only uses it for filter calls
  defp ctx, do: %{extra: %{}}

  # A filter that always passes
  defmodule AlwaysTrue do
    @behaviour ExGram.Router.Filter

    def call(_update_info, _ctx, _opts), do: true
  end

  # A filter that always fails
  defmodule AlwaysFalse do
    @behaviour ExGram.Router.Filter

    def call(_update_info, _ctx, _opts), do: false
  end

  # A filter that checks opts against update_info
  defmodule MatchCommand do
    @behaviour ExGram.Router.Filter

    def call({:command, name, _}, _ctx, expected), do: name == expected
    def call(_, _, _), do: false
  end

  defmodule Handlers do
    def handle_one(context), do: Map.put(context, :handled_by, :one)
    def handle_two(context), do: Map.put(context, :handled_by, :two)

    def handle_with_update({:command, name, _}, context), do: Map.put(context, :command_name, name)

    def fallback(context), do: Map.put(context, :handled_by, :fallback)
  end

  describe "dispatch/3 - leaf scopes" do
    test "dispatches to a matching leaf scope (1-arity handler)" do
      tree = [
        %Scope{filters: [{AlwaysTrue, nil}], handler: {Handlers, :handle_one, 1}}
      ]

      result = Dispatcher.dispatch({:text, "hello", %{}}, ctx(), tree)
      assert result.handled_by == :one
    end

    test "dispatches to a matching leaf scope (2-arity handler)" do
      tree = [
        %Scope{filters: [], handler: {Handlers, :handle_with_update, 2}}
      ]

      result = Dispatcher.dispatch({:command, :start, ""}, ctx(), tree)
      assert result.command_name == :start
    end

    test "returns context unchanged when no scope matches" do
      tree = [
        %Scope{filters: [{AlwaysFalse, nil}], handler: {Handlers, :handle_one, 1}}
      ]

      context = ctx()
      result = Dispatcher.dispatch({:text, "hello", %{}}, context, tree)
      assert result == context
    end

    test "picks the first matching scope (top-to-bottom)" do
      tree = [
        %Scope{filters: [{AlwaysTrue, nil}], handler: {Handlers, :handle_one, 1}},
        %Scope{filters: [{AlwaysTrue, nil}], handler: {Handlers, :handle_two, 1}}
      ]

      result = Dispatcher.dispatch({:text, "hello", %{}}, ctx(), tree)
      assert result.handled_by == :one
    end

    test "skips non-matching scopes and finds the first match" do
      tree = [
        %Scope{filters: [{AlwaysFalse, nil}], handler: {Handlers, :handle_one, 1}},
        %Scope{filters: [{AlwaysTrue, nil}], handler: {Handlers, :handle_two, 1}}
      ]

      result = Dispatcher.dispatch({:text, "hello", %{}}, ctx(), tree)
      assert result.handled_by == :two
    end
  end

  describe "dispatch/3 - filter AND logic" do
    test "all filters must pass" do
      tree = [
        %Scope{
          filters: [{AlwaysTrue, nil}, {AlwaysFalse, nil}],
          handler: {Handlers, :handle_one, 1}
        },
        %Scope{filters: [], handler: {Handlers, :fallback, 1}}
      ]

      result = Dispatcher.dispatch({:text, "hello", %{}}, ctx(), tree)
      assert result.handled_by == :fallback
    end

    test "scope with no filters matches everything" do
      tree = [
        %Scope{filters: [], handler: {Handlers, :handle_one, 1}}
      ]

      result = Dispatcher.dispatch({:text, "hello", %{}}, ctx(), tree)
      assert result.handled_by == :one
    end
  end

  describe "dispatch/3 - scope_extra enrichment" do
    # A filter that always passes and enriches context.extra with a marker
    defmodule EnrichingFilter do
      @behaviour ExGram.Router.Filter

      def call(_update_info, _ctx, _opts), do: true

      def scope_extra(_context, opts) do
        key = Keyword.get(opts, :key, :enriched)
        value = Keyword.get(opts, :value, true)
        %{key => value}
      end
    end

    # A filter that always passes but does not implement scope_extra
    defmodule PlainPassFilter do
      @behaviour ExGram.Router.Filter

      def call(_update_info, _ctx, _opts), do: true
    end

    defmodule ExtraCheckHandler do
      def handle(context), do: context
    end

    test "scope_extra result is merged into context.extra for child scopes" do
      tree = [
        %Scope{
          children: [
            %Scope{
              filters: [],
              handler: {ExtraCheckHandler, :handle, 1}
            }
          ],
          filters: [{EnrichingFilter, [key: :my_flag, value: :hello]}]
        }
      ]

      result = Dispatcher.dispatch({:text, "hi", %{}}, ctx(), tree)
      assert result.extra[:my_flag] == :hello
    end

    test "scope_extra is not called when filter fails" do
      tree = [
        %Scope{
          children: [
            %Scope{
              filters: [],
              handler: {ExtraCheckHandler, :handle, 1}
            }
          ],
          filters: [{AlwaysFalse, nil}]
        },
        %Scope{filters: [], handler: {Handlers, :fallback, 1}}
      ]

      result = Dispatcher.dispatch({:text, "hi", %{}}, ctx(), tree)
      assert result.handled_by == :fallback
      refute Map.has_key?(result.extra, :enriched)
    end

    test "filter without scope_extra does not enrich context" do
      tree = [
        %Scope{
          children: [
            %Scope{
              filters: [],
              handler: {ExtraCheckHandler, :handle, 1}
            }
          ],
          filters: [{PlainPassFilter, []}]
        }
      ]

      result = Dispatcher.dispatch({:text, "hi", %{}}, ctx(), tree)
      assert result.extra == %{}
    end

    test "sibling scopes do not see enrichment from other branches" do
      # Branch 1: enriches and dispatches to a non-matching child → :no_match
      # Branch 2: should NOT see the enrichment; just a plain fallback
      tree = [
        %Scope{
          filters: [{EnrichingFilter, [key: :sibling_flag, value: true]}],
          children: [
            # Child that won't match
            %Scope{filters: [{AlwaysFalse, nil}], handler: {Handlers, :handle_one, 1}}
          ]
        },
        %Scope{filters: [], handler: {Handlers, :fallback, 1}}
      ]

      result = Dispatcher.dispatch({:text, "hi", %{}}, ctx(), tree)
      assert result.handled_by == :fallback
      refute Map.has_key?(result.extra, :sibling_flag)
    end

    test "multiple enriching filters in the same scope accumulate into context" do
      tree = [
        %Scope{
          children: [
            %Scope{filters: [], handler: {ExtraCheckHandler, :handle, 1}}
          ],
          filters: [
            {EnrichingFilter, [key: :flag_a, value: 1]},
            {EnrichingFilter, [key: :flag_b, value: 2]}
          ]
        }
      ]

      result = Dispatcher.dispatch({:text, "hi", %{}}, ctx(), tree)
      assert result.extra[:flag_a] == 1
      assert result.extra[:flag_b] == 2
    end
  end

  describe "dispatch/3 - branch scopes (children)" do
    test "routes through branch into matching child" do
      tree = [
        %Scope{
          children: [
            %Scope{filters: [{MatchCommand, :start}], handler: {Handlers, :handle_one, 1}},
            %Scope{filters: [{MatchCommand, :help}], handler: {Handlers, :handle_two, 1}}
          ],
          filters: [{AlwaysTrue, nil}]
        }
      ]

      result = Dispatcher.dispatch({:command, :start, ""}, ctx(), tree)
      assert result.handled_by == :one

      result2 = Dispatcher.dispatch({:command, :help, ""}, ctx(), tree)
      assert result2.handled_by == :two
    end

    test "branch filters AND child filters both must pass" do
      tree = [
        %Scope{
          children: [
            %Scope{filters: [], handler: {Handlers, :handle_one, 1}}
          ],
          filters: [{AlwaysFalse, nil}]
        },
        %Scope{filters: [], handler: {Handlers, :fallback, 1}}
      ]

      result = Dispatcher.dispatch({:text, "hi", %{}}, ctx(), tree)
      assert result.handled_by == :fallback
    end

    test "no match in branch falls through to next top-level scope" do
      tree = [
        %Scope{
          children: [
            %Scope{filters: [{AlwaysFalse, nil}], handler: {Handlers, :handle_one, 1}}
          ],
          filters: [{AlwaysTrue, nil}]
        },
        %Scope{filters: [], handler: {Handlers, :fallback, 1}}
      ]

      result = Dispatcher.dispatch({:text, "hi", %{}}, ctx(), tree)
      assert result.handled_by == :fallback
    end

    test "deeply nested scopes work correctly" do
      tree = [
        %Scope{
          children: [
            %Scope{
              children: [
                %Scope{filters: [{MatchCommand, :admin}], handler: {Handlers, :handle_one, 1}}
              ],
              filters: [{AlwaysTrue, nil}]
            }
          ],
          filters: [{AlwaysTrue, nil}]
        }
      ]

      result = Dispatcher.dispatch({:command, :admin, ""}, ctx(), tree)
      assert result.handled_by == :one

      context = ctx()
      result2 = Dispatcher.dispatch({:command, :start, ""}, context, tree)
      assert result2 == context
    end
  end
end
