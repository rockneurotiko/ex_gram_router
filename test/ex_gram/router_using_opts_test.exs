defmodule ExGram.Router.UsingOptsTest do
  @moduledoc """
  Tests for the `aliases` and `exclude_aliases` options of `use ExGram.Router`.
  """

  use ExUnit.Case, async: false
  use ExGram.Test

  # ---------------------------------------------------------------------------
  # Support: a trivial custom filter for alias tests
  # ---------------------------------------------------------------------------

  defmodule CustomFilter do
    @behaviour ExGram.Router.Filter

    # Passes when context.extra[:custom_flag] matches opts
    @impl ExGram.Router.Filter
    def call(_update_info, context, expected) do
      Map.get(context.extra, :custom_flag) == expected
    end
  end

  defmodule AnotherFilter do
    @behaviour ExGram.Router.Filter

    @impl ExGram.Router.Filter
    def call(_update_info, context, expected) do
      Map.get(context.extra, :another_flag) == expected
    end
  end

  # ---------------------------------------------------------------------------
  # Support: handler functions
  # ---------------------------------------------------------------------------

  defmodule Handlers do
    import ExGram.Dsl

    def custom(context), do: answer(context, "custom")
    def another(context), do: answer(context, "another")
    def command_reply(context), do: answer(context, "command")
    def fallback(context), do: answer(context, "fallback")
  end

  # ---------------------------------------------------------------------------
  # Support: bot using `aliases:` option
  # ---------------------------------------------------------------------------

  defmodule AliasesBot do
    use ExGram.Bot, name: :test_aliases_bot

    use ExGram.Router,
      aliases: [
        custom: ExGram.Router.UsingOptsTest.CustomFilter,
        another: ExGram.Router.UsingOptsTest.AnotherFilter
      ]

    command("start", description: "Start")

    scope do
      filter(:custom, :active)
      handle(&ExGram.Router.UsingOptsTest.Handlers.custom/1)
    end

    scope do
      filter(:another, :enabled)
      handle(&ExGram.Router.UsingOptsTest.Handlers.another/1)
    end

    scope do
      filter(:command, :start)
      handle(&ExGram.Router.UsingOptsTest.Handlers.command_reply/1)
    end

    scope do
      handle(&ExGram.Router.UsingOptsTest.Handlers.fallback/1)
    end
  end

  # ---------------------------------------------------------------------------
  # Support: bot using `exclude_aliases:` option
  # ---------------------------------------------------------------------------

  defmodule ExcludeBot do
    use ExGram.Bot, name: :test_exclude_bot
    use ExGram.Router, exclude_aliases: [:poll, :sticker, :audio]

    command("start", description: "Start")

    # Only builtin aliases NOT excluded should work; we use :command here
    scope do
      filter(:command, :start)
      handle(&ExGram.Router.UsingOptsTest.Handlers.command_reply/1)
    end

    scope do
      handle(&ExGram.Router.UsingOptsTest.Handlers.fallback/1)
    end
  end

  # ---------------------------------------------------------------------------
  # Support: bot using both `aliases:` and `exclude_aliases:` together
  # ---------------------------------------------------------------------------

  defmodule CombinedBot do
    use ExGram.Bot, name: :test_combined_bot

    use ExGram.Router,
      aliases: [custom: ExGram.Router.UsingOptsTest.CustomFilter],
      exclude_aliases: [:poll, :sticker]

    scope do
      filter(:custom, :yes)
      handle(&ExGram.Router.UsingOptsTest.Handlers.custom/1)
    end

    scope do
      handle(&ExGram.Router.UsingOptsTest.Handlers.fallback/1)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp build_message_update(text, opts \\ []) do
    chat_id = Keyword.get(opts, :chat_id, 123)
    user_id = Keyword.get(opts, :user_id, 456)

    %ExGram.Model.Update{
      message: %ExGram.Model.Message{
        chat: %ExGram.Model.Chat{id: chat_id, type: "private"},
        date: 1_700_000_000,
        from: %ExGram.Model.User{
          first_name: "Test",
          id: user_id,
          is_bot: false,
          username: "test_user"
        },
        message_id: System.unique_integer([:positive]),
        text: text
      },
      update_id: System.unique_integer([:positive])
    }
  end

  defp stub_all_ok do
    ExGram.Test.stub(fn action, _body ->
      case action do
        :send_message -> {:ok, %{message_id: System.unique_integer([:positive]), text: "ok"}}
        :get_me -> {:ok, %{first_name: "TestBot", id: 1, is_bot: true, username: "test_bot"}}
        _ -> {:ok, %{}}
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Tests: `aliases:` option
  # ---------------------------------------------------------------------------

  describe "aliases: option" do
    setup context do
      stub_all_ok()
      {bot_name, _} = ExGram.Test.start_bot(context, AliasesBot, extra_info: %{custom_flag: :active})
      {:ok, bot_name: bot_name}
    end

    test "user-provided alias routes correctly when flag matches", %{bot_name: bot_name} do
      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "custom"
        {:ok, %{message_id: 1, text: "custom"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("anything"))
    end

    test "builtin aliases still work alongside user-provided aliases", %{bot_name: _} do
      stub_all_ok()
      {bot_name, _} = ExGram.Test.start_bot(%{test: :"builtin_still_works#{System.unique_integer()}"}, AliasesBot)

      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "command"
        {:ok, %{message_id: 1, text: "command"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("/start"))
    end

    test "second user-provided alias routes correctly", %{bot_name: _} do
      stub_all_ok()

      {bot_name, _} =
        ExGram.Test.start_bot(
          %{test: :"another_flag#{System.unique_integer()}"},
          AliasesBot,
          extra_info: %{another_flag: :enabled}
        )

      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "another"
        {:ok, %{message_id: 1, text: "another"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("hello"))
    end

    test "falls through to fallback when no alias matches", %{bot_name: _} do
      stub_all_ok()
      {bot_name, _} = ExGram.Test.start_bot(%{test: :"no_match#{System.unique_integer()}"}, AliasesBot)

      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "fallback"
        {:ok, %{message_id: 1, text: "fallback"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("hello"))
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: `exclude_aliases:` option - functional
  # ---------------------------------------------------------------------------

  describe "exclude_aliases: option - routing" do
    setup context do
      stub_all_ok()
      {bot_name, _} = ExGram.Test.start_bot(context, ExcludeBot)
      {:ok, bot_name: bot_name}
    end

    test "non-excluded builtin aliases still work", %{bot_name: bot_name} do
      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "command"
        {:ok, %{message_id: 1, text: "command"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("/start"))
    end

    test "fallback still works after excluding aliases", %{bot_name: bot_name} do
      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "fallback"
        {:ok, %{message_id: 1, text: "fallback"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("hello"))
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: `exclude_aliases:` option - compile-time rejection
  # ---------------------------------------------------------------------------

  describe "exclude_aliases: option - compile-time rejection" do
    test "using an excluded alias raises CompileError" do
      assert_raise CompileError, fn ->
        Code.compile_string("""
        defmodule ExGram.Router.UsingOptsTest.ExcludeCompileBot do
          use ExGram.Bot, name: :test_exclude_compile_bot
          use ExGram.Router, exclude_aliases: [:poll]

          scope do
            filter(:poll)
            handle(fn ctx -> ctx end)
          end
        end
        """)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: `aliases:` conflict with builtins raises CompileError
  # ---------------------------------------------------------------------------

  describe "aliases: conflict with builtins" do
    test "re-declaring a builtin alias raises CompileError" do
      assert_raise CompileError, fn ->
        Code.compile_string("""
        defmodule ExGram.Router.UsingOptsTest.ConflictBot do
          use ExGram.Bot, name: :test_conflict_bot
          use ExGram.Router, aliases: [command: SomeModule]
        end
        """)
      end
    end

    test "re-declaring a different builtin raises CompileError" do
      assert_raise CompileError, fn ->
        Code.compile_string("""
        defmodule ExGram.Router.UsingOptsTest.ConflictBot2 do
          use ExGram.Bot, name: :test_conflict_bot2
          use ExGram.Router, aliases: [text: SomeOtherModule]
        end
        """)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: combined `aliases:` and `exclude_aliases:`
  # ---------------------------------------------------------------------------

  describe "aliases: and exclude_aliases: combined" do
    setup context do
      stub_all_ok()
      {bot_name, _} = ExGram.Test.start_bot(context, CombinedBot, extra_info: %{custom_flag: :yes})
      {:ok, bot_name: bot_name}
    end

    test "user-provided alias works while excluded builtins are unavailable", %{bot_name: bot_name} do
      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "custom"
        {:ok, %{message_id: 1, text: "custom"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("anything"))
    end

    test "excluded alias in combined bot raises CompileError when used" do
      assert_raise CompileError, fn ->
        Code.compile_string("""
        defmodule ExGram.Router.UsingOptsTest.CombinedCompileBot do
          use ExGram.Bot, name: :test_combined_compile_bot
          use ExGram.Router,
            aliases: [custom: ExGram.Router.UsingOptsTest.CustomFilter],
            exclude_aliases: [:poll]

          scope do
            filter(:poll)
            handle(fn ctx -> ctx end)
          end
        end
        """)
      end
    end
  end
end
