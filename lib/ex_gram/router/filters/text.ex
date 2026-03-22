defmodule ExGram.Router.Filters.Text do
  @moduledoc """
  Built-in filter that matches plain text message updates.

  ## Usage

      # Match any text message
      filter ExGram.Router.Filters.Text
      filter :text

      # Match text exactly
      filter :text, "hello"

      # Match text against a regex
      filter :text, ~r/^\\d+$/

      # Keyword list matchers
      filter :text, prefix: "!"
      filter :text, suffix: "?"
      filter :text, contains: "hello"

  ## Options

  - `nil` — matches any text update
  - `string` — matches if the text equals the string exactly
  - `%Regex{}` — matches if the text matches the regex
  - `prefix: string` — matches if the text starts with the given prefix
  - `suffix: string` — matches if the text ends with the given suffix
  - `contains: string` — matches if the text contains the given substring
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:text, _text, _msg}, _context, nil), do: true

  def call({:text, text, _msg}, context, match) do
    ExGram.Router.Filter.text_filter(text, match, context)
  end

  def call(_update_info, _context, _opts), do: false
end
