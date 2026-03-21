defmodule ExGram.Router.Filters.Audio do
  @moduledoc """
  Filter that matches message updates containing an audio file.

  ## Usage

      filter ExGram.Router.Filters.Audio

  ## Options

  - `nil` — the only supported option; matches any audio message.
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:message, msg}, _context, _opts) do
    not is_nil(msg.audio)
  end

  def call(_update_info, _context, _opts), do: false
end
