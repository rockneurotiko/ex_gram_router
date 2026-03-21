defmodule ExGram.Router.Filters.Video do
  @moduledoc """
  Filter that matches message updates containing a video file.

  ## Usage

      filter ExGram.Router.Filters.Video

  ## Options

  - `nil` — the only supported option; matches any video message.
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:message, msg}, _context, _opts) do
    not is_nil(msg.video)
  end

  def call(_update_info, _context, _opts), do: false
end
