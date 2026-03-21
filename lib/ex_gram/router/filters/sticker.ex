defmodule ExGram.Router.Filters.Sticker do
  @moduledoc """
  Filter that matches message updates containing a sticker.

  ## Usage

      filter ExGram.Router.Filters.Sticker

  ## Options

  - `nil` — the only supported option; matches any sticker message.
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:message, msg}, _context, _opts) do
    not is_nil(msg.sticker)
  end

  def call(_update_info, _context, _opts), do: false
end
