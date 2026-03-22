defmodule ExGram.Router.Filters.PhotoTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Photo

  defp msg(overrides \\ []), do: struct(%ExGram.Model.Message{date: 0, message_id: 1}, overrides)
  defp ctx, do: %ExGram.Cnt{}

  describe "call/3" do
    test "returns true when message has photos" do
      photo_size = %ExGram.Model.PhotoSize{
        file_id: "abc",
        file_unique_id: "u",
        height: 1,
        width: 1
      }

      assert Photo.call({:message, msg(photo: [photo_size])}, ctx(), nil) == true
    end

    test "returns false when photo field is nil" do
      assert Photo.call({:message, msg(photo: nil)}, ctx(), nil) == false
    end

    test "returns false when photo list is empty" do
      assert Photo.call({:message, msg(photo: [])}, ctx(), nil) == false
    end

    test "returns false for a non-message update" do
      assert Photo.call({:command, :start, msg()}, ctx(), nil) == false
    end
  end
end
