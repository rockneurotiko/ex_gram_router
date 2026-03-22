defmodule ExGram.Router.Filters.CallbackQuery do
  @moduledoc """
  Built-in filter that matches callback query updates (inline keyboard button presses).

  ## Usage

      # Match any callback query
      filter ExGram.Router.Filters.CallbackQuery
      filter :callback_query

      # Match a specific callback data string (exact match)
      filter :callback_query, "action_a"

      # Match callback data against a regex
      filter :callback_query, ~r/^page_\\d+$/

      # Keyword list matchers
      filter :callback_query, prefix: "settings:"
      filter :callback_query, suffix: ":confirm"
      filter :callback_query, contains: "item"

  ## Options

  - `nil` — matches any callback query update
  - `string` — matches if the callback data equals the string exactly
  - `%Regex{}` — matches if the callback data matches the regex
  - `prefix: string` — matches if the callback data starts with the given prefix
  - `suffix: string` — matches if the callback data ends with the given suffix
  - `contains: string` — matches if the callback data contains the given substring
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:callback_query, _cq}, _context, nil), do: true

  def call({:callback_query, %{data: data}}, _context, match) do
    ExGram.Router.Filter.text_filter(data, match)
  end

  def call(_update_info, _context, _opts), do: false
end
