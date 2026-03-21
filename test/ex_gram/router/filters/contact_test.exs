defmodule ExGram.Router.Filters.ContactTest do
  use ExUnit.Case, async: true

  alias ExGram.Router.Filters.Contact

  defp msg(overrides \\ []), do: struct(%ExGram.Model.Message{message_id: 1, date: 0}, overrides)
  defp ctx, do: %ExGram.Cnt{}

  describe "call/3" do
    test "returns true when message has a contact" do
      contact = %ExGram.Model.Contact{phone_number: "+1234567890", first_name: "Alice"}
      assert Contact.call({:message, msg(contact: contact)}, ctx(), nil) == true
    end

    test "returns false when contact field is nil" do
      assert Contact.call({:message, msg(contact: nil)}, ctx(), nil) == false
    end

    test "returns false for a non-message update" do
      assert Contact.call({:command, :start, msg()}, ctx(), nil) == false
    end
  end
end
