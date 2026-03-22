defmodule ExGram.Router.Filters.PollTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Poll

  defp msg(overrides \\ []), do: struct(%ExGram.Model.Message{date: 0, message_id: 1}, overrides)
  defp ctx, do: %ExGram.Cnt{}

  describe "call/3" do
    test "returns true when message has a poll" do
      poll = %ExGram.Model.Poll{
        allows_multiple_answers: false,
        id: "poll1",
        is_anonymous: true,
        is_closed: false,
        options: [],
        question: "Best language?",
        total_voter_count: 0,
        type: "regular"
      }

      assert Poll.call({:message, msg(poll: poll)}, ctx(), nil) == true
    end

    test "returns false when poll field is nil" do
      assert Poll.call({:message, msg(poll: nil)}, ctx(), nil) == false
    end

    test "returns false for a non-message update" do
      assert Poll.call({:command, :start, msg()}, ctx(), nil) == false
    end
  end
end
