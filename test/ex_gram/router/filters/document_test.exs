defmodule ExGram.Router.Filters.DocumentTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Document

  defp msg(overrides \\ []), do: struct(%ExGram.Model.Message{message_id: 1, date: 0}, overrides)
  defp ctx, do: %ExGram.Cnt{}

  describe "call/3" do
    test "returns true when message has a document" do
      doc = %ExGram.Model.Document{file_id: "abc", file_unique_id: "u"}
      assert Document.call({:message, msg(document: doc)}, ctx(), nil) == true
    end

    test "returns false when document field is nil" do
      assert Document.call({:message, msg(document: nil)}, ctx(), nil) == false
    end

    test "returns false for a non-message update" do
      assert Document.call({:command, :start, msg()}, ctx(), nil) == false
    end
  end
end
