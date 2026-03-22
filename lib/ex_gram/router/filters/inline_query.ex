defmodule ExGram.Router.Filters.InlineQuery do
  @moduledoc """
  Built-in filter that matches inline query updates.

  ## Usage

      filter ExGram.Router.Filters.InlineQuery
      filter :inline_query

      # Match a specific query string (exact match)
      filter :inline_query, "search"

      # Match against a regex
      filter :inline_query, ~r/^@\\w+/

      # Keyword list matchers
      filter :inline_query, prefix: "@"
      filter :inline_query, suffix: "!"
      filter :inline_query, contains: "bot"

  ## Options

  - `nil` — matches any inline query update
  - `string` — matches if the query text equals the string exactly
  - `%Regex{}` — matches if the query text matches the regex
  - `prefix: string` — matches if the query text starts with the given prefix
  - `suffix: string` — matches if the query text ends with the given suffix
  - `contains: string` — matches if the query text contains the given substring
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:inline_query, _iq}, _context, nil), do: true

  def call({:inline_query, %{query: query}}, _context, match) do
    ExGram.Router.Filter.text_filter(query, match)
  end

  def call(_update_info, _context, _opts), do: false
end
