defmodule ExGram.RouterTest do
  @moduledoc """
  Integration tests for ExGram.Router using ExGram's test adapter.

  These tests exercise the full pipeline: DSL macros → compile-time tree build →
  runtime dispatch via ExGram's dispatcher → handler execution.
  """

  use ExUnit.Case, async: false
  use ExGram.Test

  # ---------------------------------------------------------------------------
  # Support: a custom filter for testing
  # ---------------------------------------------------------------------------

  defmodule StateFilter do
    @behaviour ExGram.Router.Filter

    # opts is either an atom (matches extra[:state]) or
    # a {key, value} tuple for matching a nested key in extra.
    @impl ExGram.Router.Filter
    def call(_update_info, context, {key, expected}) do
      Map.get(context.extra, key) == expected
    end

    def call(_update_info, context, expected_state) do
      Map.get(context.extra, :state) == expected_state
    end
  end

  # ---------------------------------------------------------------------------
  # Support: handler functions (capture targets)
  # ---------------------------------------------------------------------------

  defmodule Handlers do
    import ExGram.Dsl

    def start(context) do
      answer(context, "Welcome!")
    end

    def help(context), do: answer(context, "Help text")
    def echo({:command, _name, %{text: text}}, context), do: answer(context, text)
    def got_name(context), do: answer(context, "Got name")
    def got_email(context), do: answer(context, "Got email")
    def admin({:command, :admin, _}, context), do: answer(context, "Admin panel")
    def handle_text(context), do: answer(context, "Text received")
    def fallback(context), do: answer(context, "Fallback")

    # callback_query propagation handlers
    def change_project(context), do: answer_callback(context, context.update, text: "Change project")
    def delete_project(context), do: answer_callback(context, context.update, text: "Delete project")
    def volume(context), do: answer_callback(context, context.update, text: "Volume")
    def mute(context), do: answer_callback(context, context.update, text: "Mute")
  end

  # ---------------------------------------------------------------------------
  # Support: test bot definition using ExGram.Router
  # ---------------------------------------------------------------------------

  defmodule TestBot do
    use ExGram.Bot, name: :test_router_bot
    use ExGram.Router

    alias_filter(ExGram.RouterTest.StateFilter, as: :state)

    command("start", description: "Start")
    command("help", description: "Help")
    command("echo", description: "Echo")
    command("admin", description: "Admin")

    # /start command
    scope do
      filter(:command, :start)
      handle(&ExGram.RouterTest.Handlers.start/1)
    end

    # /help command
    scope do
      filter(:command, :help)
      handle(&ExGram.RouterTest.Handlers.help/1)
    end

    # /echo command - 2-arity handler receives (update_info, context)
    scope do
      filter(:command, :echo)
      handle(&ExGram.RouterTest.Handlers.echo/2)
    end

    # State-gated registration scope (branch)
    scope do
      filter(:state, :registration)

      scope do
        filter(:text)
        filter(:state, {:sub_state, :get_name})
        handle(&ExGram.RouterTest.Handlers.got_name/1)
      end

      scope do
        filter(:text)
        filter(:state, {:sub_state, :get_email})
        handle(&ExGram.RouterTest.Handlers.got_email/1)
      end

      # Admin sub-scope
      scope do
        filter(:command, :admin)
        handle(&ExGram.RouterTest.Handlers.admin/2)
      end
    end

    # Fallback: matches everything
    scope do
      handle(&ExGram.RouterTest.Handlers.fallback/1)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp build_callback_query_update(data, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, 456)

    %ExGram.Model.Update{
      callback_query: %ExGram.Model.CallbackQuery{
        chat_instance: "chat_instance_#{System.unique_integer([:positive])}",
        data: data,
        from: %ExGram.Model.User{
          first_name: "Test",
          id: user_id,
          is_bot: false,
          username: "test_user"
        },
        id: "cq_#{System.unique_integer([:positive])}"
      },
      update_id: System.unique_integer([:positive])
    }
  end

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

  defp start_bot(context, opts \\ []) do
    stub_all_ok()
    ExGram.Test.start_bot(context, TestBot, opts)
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "command routing" do
    setup context do
      {bot_name, _} = start_bot(context)
      {:ok, bot_name: bot_name}
    end

    test "/start dispatches to start handler", %{bot_name: bot_name} do
      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "Welcome!"
        {:ok, %{message_id: 1, text: "Welcome!"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("/start"))
    end

    test "/help dispatches to help handler", %{bot_name: bot_name} do
      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "Help text"
        {:ok, %{message_id: 1, text: "Help text"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("/help"))
    end

    test "/echo with 2-arity handler passes update_info", %{bot_name: bot_name} do
      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "hello world"
        {:ok, %{message_id: 1, text: "hello world"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("/echo hello world"))
    end
  end

  describe "fallback routing" do
    setup context do
      {bot_name, _} = start_bot(context)
      {:ok, bot_name: bot_name}
    end

    test "unmatched text falls through to fallback", %{bot_name: bot_name} do
      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "Fallback"
        {:ok, %{message_id: 1, text: "Fallback"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("just some text"))
    end

    test "unknown command falls through to fallback", %{bot_name: bot_name} do
      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "Fallback"
        {:ok, %{message_id: 1, text: "Fallback"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("/unknown_command"))
    end
  end

  describe "state-gated scope routing" do
    test "text in :registration + :get_name state routes correctly", context do
      {bot_name, _} =
        start_bot(context, extra_info: %{state: :registration, sub_state: :get_name})

      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "Got name"
        {:ok, %{message_id: 1, text: "Got name"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("John Doe"))
    end

    test "text in :registration + :get_email state routes correctly", context do
      {bot_name, _} =
        start_bot(context, extra_info: %{state: :registration, sub_state: :get_email})

      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "Got email"
        {:ok, %{message_id: 1, text: "Got email"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("user@example.com"))
    end

    test "text without :registration state falls through to fallback", context do
      {bot_name, _} = start_bot(context, extra_info: %{state: :idle})

      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "Fallback"
        {:ok, %{message_id: 1, text: "Fallback"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("John Doe"))
    end

    test "/admin command in :registration state routes to admin handler", context do
      {bot_name, _} =
        start_bot(context, extra_info: %{state: :registration})

      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "Admin panel"
        {:ok, %{message_id: 1, text: "Admin panel"}}
      end)

      ExGram.Test.push_update(bot_name, build_message_update("/admin"))
    end
  end

  # ---------------------------------------------------------------------------
  # Support: a second bot for callback_query propagation tests
  # ---------------------------------------------------------------------------

  defmodule PropagatingBot do
    use ExGram.Bot, name: :test_propagating_bot
    use ExGram.Router

    # Parent scope: prefix "proj:" propagates to children
    scope do
      filter(:callback_query, prefix: "proj:", propagate: true)

      scope do
        filter(:callback_query, "change")
        handle(&ExGram.RouterTest.Handlers.change_project/1)
      end

      scope do
        filter(:callback_query, "delete")
        handle(&ExGram.RouterTest.Handlers.delete_project/1)
      end

      # Nested propagation: "proj:settings:" prefix
      scope do
        filter(:callback_query, prefix: "settings:", propagate: true)

        scope do
          filter(:callback_query, "volume")
          handle(&ExGram.RouterTest.Handlers.volume/1)
        end

        scope do
          filter(:callback_query, "mute")
          handle(&ExGram.RouterTest.Handlers.mute/1)
        end
      end
    end

    scope do
      handle(&ExGram.RouterTest.Handlers.fallback/1)
    end
  end

  defp start_propagating_bot(context) do
    stub_all_ok()
    ExGram.Test.start_bot(context, PropagatingBot)
  end

  describe "callback_query prefix propagation" do
    setup context do
      {bot_name, _} = start_propagating_bot(context)
      {:ok, bot_name: bot_name}
    end

    test "parent prefix propagates: 'proj:change' routes to change_project handler",
         %{bot_name: bot_name} do
      ExGram.Test.expect(:answer_callback_query, fn body ->
        assert body[:text] == "Change project"
        {:ok, true}
      end)

      ExGram.Test.push_update(bot_name, build_callback_query_update("proj:change"))
    end

    test "parent prefix propagates: 'proj:delete' routes to delete_project handler",
         %{bot_name: bot_name} do
      ExGram.Test.expect(:answer_callback_query, fn body ->
        assert body[:text] == "Delete project"
        {:ok, true}
      end)

      ExGram.Test.push_update(bot_name, build_callback_query_update("proj:delete"))
    end

    test "nested prefix propagation: 'proj:settings:volume' routes to volume handler",
         %{bot_name: bot_name} do
      ExGram.Test.expect(:answer_callback_query, fn body ->
        assert body[:text] == "Volume"
        {:ok, true}
      end)

      ExGram.Test.push_update(bot_name, build_callback_query_update("proj:settings:volume"))
    end

    test "nested prefix propagation: 'proj:settings:mute' routes to mute handler",
         %{bot_name: bot_name} do
      ExGram.Test.expect(:answer_callback_query, fn body ->
        assert body[:text] == "Mute"
        {:ok, true}
      end)

      ExGram.Test.push_update(bot_name, build_callback_query_update("proj:settings:mute"))
    end

    test "callback without the parent prefix falls through to fallback",
         %{bot_name: bot_name} do
      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "Fallback"
        {:ok, %{message_id: 1, text: "Fallback"}}
      end)

      ExGram.Test.push_update(bot_name, build_callback_query_update("other:action"))
    end

    test "non-propagated prefix match does NOT route children without full prefix",
         %{bot_name: bot_name} do
      # "change" alone (without "proj:") should NOT match — it would need "proj:change"
      ExGram.Test.expect(:send_message, fn body ->
        assert body[:text] == "Fallback"
        {:ok, %{message_id: 1, text: "Fallback"}}
      end)

      ExGram.Test.push_update(bot_name, build_callback_query_update("change"))
    end
  end

  describe "__exgram_routing_tree__/0" do
    test "is generated and returns the routing tree" do
      tree = TestBot.__exgram_routing_tree__()
      assert is_list(tree)
      refute Enum.empty?(tree)

      Enum.each(tree, fn scope ->
        assert %ExGram.Router.Scope{} = scope
      end)
    end
  end
end
