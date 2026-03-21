defmodule ExGram.Router.Filters.Voice do
  @moduledoc """
  Filter that matches message updates containing a voice message.

  ## Usage

      filter ExGram.Router.Filters.Voice

  ## Options

  - `nil` — the only supported option; matches any voice message.
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:message, msg}, _context, _opts) do
    not is_nil(msg.voice)
  end

  def call(_update_info, _context, _opts), do: false
end
