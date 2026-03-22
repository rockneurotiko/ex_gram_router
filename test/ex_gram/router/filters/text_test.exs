defmodule ExGram.Router.Filters.TextTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Text

  @ctx %{}

  describe "call/3" do
    test "matches any text when opts is nil" do
      assert Text.call({:text, "hello", %{}}, @ctx, nil) == true
      assert Text.call({:text, "", %{}}, @ctx, nil) == true
    end

    test "matches text exactly" do
      assert Text.call({:text, "hello", %{}}, @ctx, "hello") == true
      refute Text.call({:text, "hello world", %{}}, @ctx, "hello")
      refute Text.call({:text, "hello world", %{}}, @ctx, "xyz")
    end

    test "matches text with prefix keyword" do
      assert Text.call({:text, "!start", %{}}, @ctx, prefix: "!") == true
      refute Text.call({:text, "hello", %{}}, @ctx, prefix: "!")
    end

    test "matches text with suffix keyword" do
      assert Text.call({:text, "hello?", %{}}, @ctx, suffix: "?") == true
      refute Text.call({:text, "hello", %{}}, @ctx, suffix: "?")
    end

    test "matches text with contains keyword" do
      assert Text.call({:text, "hello world", %{}}, @ctx, contains: "hello") == true
      assert Text.call({:text, "hello world", %{}}, @ctx, contains: "world") == true
      refute Text.call({:text, "hello world", %{}}, @ctx, contains: "xyz")
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
