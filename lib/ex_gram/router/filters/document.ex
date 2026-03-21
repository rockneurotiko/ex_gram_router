defmodule ExGram.Router.Filters.Document do
  @moduledoc """
  Filter that matches message updates containing a document (file).

  ## Usage

      filter ExGram.Router.Filters.Document

  ## Options

  - `nil` — the only supported option; matches any document message.
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:message, msg}, _context, _opts) do
    not is_nil(msg.document)
  end

  def call(_update_info, _context, _opts), do: false
end
