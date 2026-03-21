defmodule ExGram.Router.Filters.CallbackQuery do
  @moduledoc """
  Built-in filter that matches callback query updates (inline keyboard button presses).

  ## Usage

      # Match any callback query
      filter ExGram.Router.Filters.CallbackQuery
      filter :callback_query

      # Match a specific callback data string
      filter :callback_query, "action_a"

      # Match callback data against a regex
      filter :callback_query, ~r/^page_\\d+$/

  ## Options

  - `nil` — matches any callback query update
  - `string` — matches if the callback data equals the string exactly
  - `%Regex{}` — matches if the callback data matches the regex
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:callback_query, _cq}, _context, nil), do: true

  def call({:callback_query, %{data: data}}, _context, %Regex{} = regex) when is_binary(data) do
    String.match?(data, regex)
  end

  def call({:callback_query, %{data: data}}, _context, expected) when is_binary(expected) and is_binary(data) do
    data == expected
  end

  def call(_update_info, _context, _opts), do: false
end
