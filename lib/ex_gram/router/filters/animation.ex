defmodule ExGram.Router.Filters.Animation do
  @moduledoc """
  Filter that matches message updates containing an animation (GIF or H.264/MPEG-4 AVC).

  ## Usage

      filter ExGram.Router.Filters.Animation

  ## Options

  - `nil` — the only supported option; matches any animation message.
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:message, msg}, _context, _opts) do
    not is_nil(msg.animation)
  end

  def call(_update_info, _context, _opts), do: false
end
