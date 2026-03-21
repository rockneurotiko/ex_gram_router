defmodule ExGram.Router.Filters.Contact do
  @moduledoc """
  Filter that matches message updates containing a shared contact.

  ## Usage

      filter ExGram.Router.Filters.Contact

  ## Options

  - `nil` — the only supported option; matches any contact message.
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:message, msg}, _context, _opts) do
    not is_nil(msg.contact)
  end

  def call(_update_info, _context, _opts), do: false
end
