defmodule ExGram.Router.Filters.CommandTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Command

  # Filters receive (update_info, context, opts). Context is not used by this filter.
  @ctx %{}

  describe "call/3" do
    test "matches any command when opts is nil" do
      assert Command.call({:command, :start, ""}, @ctx, nil) == true
      assert Command.call({:command, :help, "some text"}, @ctx, nil) == true
      assert Command.call({:command, "unknown", ""}, @ctx, nil) == true
    end

    test "matches a specific atom command" do
      assert Command.call({:command, :start, ""}, @ctx, :start) == true
      refute Command.call({:command, :help, ""}, @ctx, :start) == true
    end

    test "matches a specific string command (undeclared)" do
      assert Command.call({:command, "unknown", ""}, @ctx, "unknown") == true
      refute Command.call({:command, "other", ""}, @ctx, "unknown") == true
    end

    test "does not match non-command updates" do
      refute Command.call({:text, "hello", %{}}, @ctx, nil)
      refute Command.call({:callback_query, %{data: "x"}}, @ctx, nil)
      refute Command.call({:location, %{}}, @ctx, nil)
      refute Command.call({:message, %{}}, @ctx, nil)
    end
  end
end
