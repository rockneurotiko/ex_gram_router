defmodule ExGram.Router.Filters.InlineQueryTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.InlineQuery

  @ctx %{}

  describe "call/3" do
    test "matches any inline query when opts is nil" do
      assert InlineQuery.call({:inline_query, %{query: "search"}}, @ctx, nil) == true
      assert InlineQuery.call({:inline_query, %{query: ""}}, @ctx, nil) == true
    end

    test "matches exact query string" do
      assert InlineQuery.call({:inline_query, %{query: "search"}}, @ctx, "search") == true
      refute InlineQuery.call({:inline_query, %{query: "search results"}}, @ctx, "search")
    end

    test "matches query against a regex" do
      assert InlineQuery.call({:inline_query, %{query: "@username"}}, @ctx, ~r/^@\w+/) == true
      refute InlineQuery.call({:inline_query, %{query: "plain text"}}, @ctx, ~r/^@\w+/)
    end

    test "matches query with prefix keyword" do
      assert InlineQuery.call({:inline_query, %{query: "@user"}}, @ctx, prefix: "@") == true
      refute InlineQuery.call({:inline_query, %{query: "user"}}, @ctx, prefix: "@")
    end

    test "matches query with suffix keyword" do
      assert InlineQuery.call({:inline_query, %{query: "search!"}}, @ctx, suffix: "!") == true
      refute InlineQuery.call({:inline_query, %{query: "search"}}, @ctx, suffix: "!")
    end

    test "matches query with contains keyword" do
      assert InlineQuery.call({:inline_query, %{query: "find bot here"}}, @ctx, contains: "bot") == true
      refute InlineQuery.call({:inline_query, %{query: "find here"}}, @ctx, contains: "bot")
    end

    test "does not match non-inline-query updates" do
      refute InlineQuery.call({:command, :start, ""}, @ctx, nil)
      refute InlineQuery.call({:text, "hello", %{}}, @ctx, nil)
      refute InlineQuery.call({:callback_query, %{data: "x"}}, @ctx, nil)
    end
  end
end
