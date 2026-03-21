defmodule ExGram.Router.Filters.VideoTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Video

  defp msg(overrides \\ []), do: struct(%ExGram.Model.Message{message_id: 1, date: 0}, overrides)
  defp ctx, do: %ExGram.Cnt{}

  describe "call/3" do
    test "returns true when message has a video" do
      video = %ExGram.Model.Video{
        file_id: "abc",
        file_unique_id: "u",
        width: 640,
        height: 480,
        duration: 5
      }

      assert Video.call({:message, msg(video: video)}, ctx(), nil) == true
    end

    test "returns false when video field is nil" do
      assert Video.call({:message, msg(video: nil)}, ctx(), nil) == false
    end

    test "returns false for a non-message update" do
      assert Video.call({:command, :start, msg()}, ctx(), nil) == false
    end
  end
end
