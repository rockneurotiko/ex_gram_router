defmodule ExGram.Router.Filters.InlineQuery do
  @moduledoc """
  Built-in filter that matches inline query updates.

  ## Usage

      filter ExGram.Router.Filters.InlineQuery
      filter :inline_query

      # Match a specific query string
      filter :inline_query, "search"

      # Match against a regex
      filter :inline_query, ~r/^@\\w+/

  ## Options

  - `nil` — matches any inline query update
  - `string` — matches if the query text equals the string exactly
  - `%Regex{}` — matches if the query text matches the regex
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:inline_query, _iq}, _context, nil), do: true

  def call({:inline_query, %{query: query}}, _context, %Regex{} = regex) when is_binary(query) do
    String.match?(query, regex)
  end

  def call({:inline_query, %{query: query}}, _context, expected) when is_binary(expected) and is_binary(query) do
    query == expected
  end

  def call(_update_info, _context, _opts), do: false
end
