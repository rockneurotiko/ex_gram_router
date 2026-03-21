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

  describe "dispatch/3 - branch scopes (children)" do
    test "routes through branch into matching child" do
      tree = [
        %Scope{
          filters: [{AlwaysTrue, nil}],
          children: [
            %Scope{filters: [{MatchCommand, :start}], handler: {Handlers, :handle_one, 1}},
            %Scope{filters: [{MatchCommand, :help}], handler: {Handlers, :handle_two, 1}}
          ]
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
          filters: [{AlwaysFalse, nil}],
          children: [
            %Scope{filters: [], handler: {Handlers, :handle_one, 1}}
          ]
        },
        %Scope{filters: [], handler: {Handlers, :fallback, 1}}
      ]

      result = Dispatcher.dispatch({:text, "hi", %{}}, ctx(), tree)
      assert result.handled_by == :fallback
    end

    test "no match in branch falls through to next top-level scope" do
      tree = [
        %Scope{
          filters: [{AlwaysTrue, nil}],
          children: [
            %Scope{filters: [{AlwaysFalse, nil}], handler: {Handlers, :handle_one, 1}}
          ]
        },
        %Scope{filters: [], handler: {Handlers, :fallback, 1}}
      ]

      result = Dispatcher.dispatch({:text, "hi", %{}}, ctx(), tree)
      assert result.handled_by == :fallback
    end

    test "deeply nested scopes work correctly" do
      tree = [
        %Scope{
          filters: [{AlwaysTrue, nil}],
          children: [
            %Scope{
              filters: [{AlwaysTrue, nil}],
              children: [
                %Scope{filters: [{MatchCommand, :admin}], handler: {Handlers, :handle_one, 1}}
              ]
            }
          ]
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
