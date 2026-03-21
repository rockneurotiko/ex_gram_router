defmodule ExGram.Router.Filters.Photo do
  @moduledoc """
  Filter that matches message updates containing one or more photos.

  ## Usage

      filter ExGram.Router.Filters.Photo

  ## Options

  - `nil` — the only supported option; matches any photo message.
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:message, msg}, _context, _opts) do
    not is_nil(msg.photo) and msg.photo != []
  end

  def call(_update_info, _context, _opts), do: false
end
