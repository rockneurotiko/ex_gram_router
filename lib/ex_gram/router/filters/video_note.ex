defmodule ExGram.Router.Filters.VideoNote do
  @moduledoc """
  Filter that matches message updates containing a video note (round video).

  ## Usage

      filter ExGram.Router.Filters.VideoNote

  ## Options

  - `nil` — the only supported option; matches any video note message.
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:message, msg}, _context, _opts) do
    not is_nil(msg.video_note)
  end

  def call(_update_info, _context, _opts), do: false
end
