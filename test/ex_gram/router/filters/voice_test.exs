defmodule ExGram.Router.Filters.VoiceTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Voice

  defp msg(overrides \\ []), do: struct(%ExGram.Model.Message{message_id: 1, date: 0}, overrides)
  defp ctx, do: %ExGram.Cnt{}

  describe "call/3" do
    test "returns true when message has a voice message" do
      voice = %ExGram.Model.Voice{file_id: "abc", file_unique_id: "u", duration: 5}
      assert Voice.call({:message, msg(voice: voice)}, ctx(), nil) == true
    end

    test "returns false when voice field is nil" do
      assert Voice.call({:message, msg(voice: nil)}, ctx(), nil) == false
    end

    test "returns false for a non-message update" do
      assert Voice.call({:command, :start, msg()}, ctx(), nil) == false
    end
  end
end
