defmodule ExGram.Router.Filters.Poll do
  @moduledoc """
  Filter that matches message updates containing a poll.

  ## Usage

      filter ExGram.Router.Filters.Poll

  ## Options

  - `nil` — the only supported option; matches any poll message.
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:message, msg}, _context, _opts) do
    not is_nil(msg.poll)
  end

  def call(_update_info, _context, _opts), do: false
end
