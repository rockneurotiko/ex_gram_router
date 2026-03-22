defmodule ExGram.Router.Filters.AnimationTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Animation

  defp msg(overrides \\ []), do: struct(%ExGram.Model.Message{date: 0, message_id: 1}, overrides)
  defp ctx, do: %ExGram.Cnt{}

  describe "call/3" do
    test "returns true when message has an animation" do
      animation = %ExGram.Model.Animation{
        duration: 3,
        file_id: "abc",
        file_unique_id: "u",
        height: 240,
        width: 320
      }

      assert Animation.call({:message, msg(animation: animation)}, ctx(), nil) == true
    end

    test "returns false when animation field is nil" do
      assert Animation.call({:message, msg(animation: nil)}, ctx(), nil) == false
    end

    test "returns false for a non-message update" do
      assert Animation.call({:command, :start, msg()}, ctx(), nil) == false
    end
  end
end
