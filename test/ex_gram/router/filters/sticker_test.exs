defmodule ExGram.Router.Filters.StickerTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Sticker

  defp msg(overrides \\ []), do: struct(%ExGram.Model.Message{date: 0, message_id: 1}, overrides)
  defp ctx, do: %ExGram.Cnt{}

  describe "call/3" do
    test "returns true when message has a sticker" do
      sticker = %ExGram.Model.Sticker{
        file_id: "abc",
        file_unique_id: "u",
        height: 512,
        is_animated: false,
        is_video: false,
        type: "regular",
        width: 512
      }

      assert Sticker.call({:message, msg(sticker: sticker)}, ctx(), nil) == true
    end

    test "returns false when sticker field is nil" do
      assert Sticker.call({:message, msg(sticker: nil)}, ctx(), nil) == false
    end

    test "returns false for a non-message update" do
      assert Sticker.call({:command, :start, msg()}, ctx(), nil) == false
    end
  end
end
