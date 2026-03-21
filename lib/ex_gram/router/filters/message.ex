defmodule ExGram.Router.Filters.Message do
  @moduledoc """
  Built-in filter that matches generic message updates (photos, documents,
  stickers, audio, video, etc. — any message that is not text or a command).

  ## Usage

      filter ExGram.Router.Filters.Message
      filter :message

  ## Options

  - `nil` — matches any `:message` update (the only supported option)
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:message, _msg}, _context, _opts), do: true
  def call(_update_info, _context, _opts), do: false
end
