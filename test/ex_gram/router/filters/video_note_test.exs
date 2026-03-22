defmodule ExGram.Router.Filters.VideoNoteTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.VideoNote

  defp msg(overrides \\ []), do: struct(%ExGram.Model.Message{date: 0, message_id: 1}, overrides)
  defp ctx, do: %ExGram.Cnt{}

  describe "call/3" do
    test "returns true when message has a video note" do
      video_note = %ExGram.Model.VideoNote{
        duration: 5,
        file_id: "abc",
        file_unique_id: "u",
        length: 240
      }

      assert VideoNote.call({:message, msg(video_note: video_note)}, ctx(), nil) == true
    end

    test "returns false when video_note field is nil" do
      assert VideoNote.call({:message, msg(video_note: nil)}, ctx(), nil) == false
    end

    test "returns false for a non-message update" do
      assert VideoNote.call({:command, :start, msg()}, ctx(), nil) == false
    end
  end
end
