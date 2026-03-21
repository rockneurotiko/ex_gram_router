defmodule ExGram.Router.Filters.TextTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Text

  @ctx %{}

  describe "call/3" do
    test "matches any text when opts is nil" do
      assert Text.call({:text, "hello", %{}}, @ctx, nil) == true
      assert Text.call({:text, "", %{}}, @ctx, nil) == true
    end

    test "matches text containing a substring" do
      assert Text.call({:text, "hello world", %{}}, @ctx, "hello") == true
      assert Text.call({:text, "hello world", %{}}, @ctx, "world") == true
      refute Text.call({:text, "hello world", %{}}, @ctx, "xyz")
    end

    test "matches text against a regex" do
      assert Text.call({:text, "foo@bar.com", %{}}, @ctx, ~r/@/) == true
      assert Text.call({:text, "12345", %{}}, @ctx, ~r/^\d+$/) == true
      refute Text.call({:text, "not an email", %{}}, @ctx, ~r/^\d+$/)
    end

    test "does not match non-text updates" do
      refute Text.call({:command, :start, ""}, @ctx, nil)
      refute Text.call({:callback_query, %{data: "x"}}, @ctx, nil)
      refute Text.call({:location, %{}}, @ctx, nil)
    end
  end
end
