defmodule ExGram.Router.Filters.RegexTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Regex, as: RegexFilter

  @ctx %{}

  describe "call/3" do
    test "matches any regex update when opts is nil" do
      assert RegexFilter.call({:regex, :email, %{}}, @ctx, nil) == true
      assert RegexFilter.call({:regex, :phone, "some text"}, @ctx, nil) == true
    end

    test "matches a specific named regex update" do
      assert RegexFilter.call({:regex, :email, %{}}, @ctx, :email) == true
      refute RegexFilter.call({:regex, :phone, %{}}, @ctx, :email)
    end

    test "does not match non-regex updates" do
      refute RegexFilter.call({:command, :start, ""}, @ctx, nil)
      refute RegexFilter.call({:text, "hello", %{}}, @ctx, nil)
      refute RegexFilter.call({:callback_query, %{data: "x"}}, @ctx, nil)
      refute RegexFilter.call({:message, %{}}, @ctx, nil)
    end
  end
end
