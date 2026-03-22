defmodule ExGram.Router.Filters.CallbackQueryTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.CallbackQuery

  @ctx %ExGram.Cnt{}

  defp ctx_with_prefix(prefix) do
    %ExGram.Cnt{extra: %{__exgram_router__: %{text_prefix: prefix}}}
  end

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

    test "matches prefix option" do
      assert CallbackQuery.call(
               {:callback_query, %{data: "settings:volume"}},
               @ctx,
               prefix: "settings:"
             )

      refute CallbackQuery.call(
               {:callback_query, %{data: "other:volume"}},
               @ctx,
               prefix: "settings:"
             )
    end

    test "matches suffix option" do
      assert CallbackQuery.call(
               {:callback_query, %{data: "action:confirm"}},
               @ctx,
               suffix: ":confirm"
             )

      refute CallbackQuery.call(
               {:callback_query, %{data: "action:cancel"}},
               @ctx,
               suffix: ":confirm"
             )
    end

    test "matches contains option" do
      assert CallbackQuery.call(
               {:callback_query, %{data: "a:item:b"}},
               @ctx,
               contains: "item"
             )

      refute CallbackQuery.call(
               {:callback_query, %{data: "a:other:b"}},
               @ctx,
               contains: "item"
             )
    end
  end

  describe "call/3 with accumulated prefix from context" do
    test "exact string match prepends accumulated prefix" do
      ctx = ctx_with_prefix("proj:")
      # Child has filter :callback_query, "change" → should match "proj:change"
      assert CallbackQuery.call({:callback_query, %{data: "proj:change"}}, ctx, "change")
      refute CallbackQuery.call({:callback_query, %{data: "change"}}, ctx, "change")
    end

    test "prefix option prepends accumulated prefix" do
      ctx = ctx_with_prefix("proj:")
      # Child has filter :callback_query, prefix: "settings:" → matches "proj:settings:..."
      assert CallbackQuery.call(
               {:callback_query, %{data: "proj:settings:volume"}},
               ctx,
               prefix: "settings:"
             )

      refute CallbackQuery.call(
               {:callback_query, %{data: "settings:volume"}},
               ctx,
               prefix: "settings:"
             )
    end

    test "regex match ignores accumulated prefix (regexes are absolute)" do
      ctx = ctx_with_prefix("proj:")
      # Regex tests the raw data, prefix is not prepended
      assert CallbackQuery.call(
               {:callback_query, %{data: "proj:change"}},
               ctx,
               ~r/^proj:change$/
             )
    end

    test "suffix and contains are unaffected by accumulated prefix" do
      ctx = ctx_with_prefix("proj:")

      assert CallbackQuery.call(
               {:callback_query, %{data: "proj:action:confirm"}},
               ctx,
               suffix: ":confirm"
             )

      assert CallbackQuery.call(
               {:callback_query, %{data: "proj:a:item:b"}},
               ctx,
               contains: "item"
             )
    end

    test "no accumulated prefix behaves as before" do
      assert CallbackQuery.call({:callback_query, %{data: "change"}}, @ctx, "change")
    end
  end

  describe "scope_extra/2" do
    test "returns empty map when opts is nil" do
      assert CallbackQuery.scope_extra(@ctx, nil) == %{}
    end

    test "returns empty map when propagate is not set" do
      assert CallbackQuery.scope_extra(@ctx, prefix: "proj:") == %{}
    end

    test "returns empty map when propagate is false" do
      assert CallbackQuery.scope_extra(@ctx, prefix: "proj:", propagate: false) == %{}
    end

    test "returns text_prefix when propagate: true" do
      result = CallbackQuery.scope_extra(@ctx, prefix: "proj:", propagate: true)
      assert result == %{__exgram_router__: %{text_prefix: "proj:"}}
    end

    test "accumulates prefix on top of existing context prefix" do
      ctx = ctx_with_prefix("proj:")
      result = CallbackQuery.scope_extra(ctx, prefix: "settings:", propagate: true)
      assert result == %{__exgram_router__: %{text_prefix: "proj:settings:"}}
    end

    test "handles missing __exgram_router__ key gracefully" do
      ctx = %ExGram.Cnt{extra: %{}}
      result = CallbackQuery.scope_extra(ctx, prefix: "proj:", propagate: true)
      assert result == %{__exgram_router__: %{text_prefix: "proj:"}}
    end

    test "handles empty prefix gracefully" do
      result = CallbackQuery.scope_extra(@ctx, prefix: "", propagate: true)
      assert result == %{__exgram_router__: %{text_prefix: ""}}
    end

    test "returns empty map when opts is not a list" do
      assert CallbackQuery.scope_extra(@ctx, "action_a") == %{}
      assert CallbackQuery.scope_extra(@ctx, ~r/regex/) == %{}
    end
  end
end
