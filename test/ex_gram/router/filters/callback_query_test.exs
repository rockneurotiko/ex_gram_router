defmodule ExGram.Router.Filters.CallbackQueryTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.CallbackQuery

  @ctx %{}

  describe "call/3" do
    test "matches any callback query when opts is nil" do
      assert CallbackQuery.call({:callback_query, %{data: "action_a"}}, @ctx, nil) == true
      assert CallbackQuery.call({:callback_query, %{data: nil}}, @ctx, nil) == true
    end

    test "matches exact callback data string" do
      assert CallbackQuery.call({:callback_query, %{data: "action_a"}}, @ctx, "action_a") == true
      refute CallbackQuery.call({:callback_query, %{data: "action_b"}}, @ctx, "action_a")
    end

    test "matches callback data against a regex" do
      assert CallbackQuery.call({:callback_query, %{data: "page_3"}}, @ctx, ~r/^page_\d+$/) ==
               true

      refute CallbackQuery.call({:callback_query, %{data: "menu"}}, @ctx, ~r/^page_\d+$/)
    end

    test "does not match when data is nil and opts is a string" do
      refute CallbackQuery.call({:callback_query, %{data: nil}}, @ctx, "action_a")
    end

    test "does not match non-callback updates" do
      refute CallbackQuery.call({:command, :start, ""}, @ctx, nil)
      refute CallbackQuery.call({:text, "hello", %{}}, @ctx, nil)
    end
  end
end
