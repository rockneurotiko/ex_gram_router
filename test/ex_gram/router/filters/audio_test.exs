defmodule ExGram.Router.Filters.AudioTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Audio

  defp msg(overrides \\ []), do: struct(%ExGram.Model.Message{date: 0, message_id: 1}, overrides)
  defp ctx, do: %ExGram.Cnt{}

  describe "call/3" do
    test "returns true when message has an audio file" do
      audio = %ExGram.Model.Audio{duration: 10, file_id: "abc", file_unique_id: "u"}
      assert Audio.call({:message, msg(audio: audio)}, ctx(), nil) == true
    end

    test "returns false when audio field is nil" do
      assert Audio.call({:message, msg(audio: nil)}, ctx(), nil) == false
    end

    test "returns false for a non-message update" do
      assert Audio.call({:command, :start, msg()}, ctx(), nil) == false
    end
  end
end
