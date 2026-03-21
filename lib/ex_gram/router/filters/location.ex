defmodule ExGram.Router.Filters.Location do
  @moduledoc """
  Built-in filter that matches location message updates.

  ## Usage

      filter ExGram.Router.Filters.Location
      filter :location

  ## Options

  - `nil` — matches any location update (the only supported option)
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:location, _location}, _context, _opts), do: true
  def call(_update_info, _context, _opts), do: false
end
