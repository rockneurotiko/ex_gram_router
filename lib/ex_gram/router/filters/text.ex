defmodule ExGram.Router.Filters.Text do
  @moduledoc """
  Built-in filter that matches plain text message updates.

  ## Usage

      # Match any text message
      filter ExGram.Router.Filters.Text
      filter :text

      # Match text containing a specific substring
      filter :text, "hello"

      # Match text against a regex
      filter :text, ~r/^\\d+$/

  ## Options

  - `nil` — matches any text update
  - `string` — matches if the text contains the string (case-sensitive)
  - `%Regex{}` — matches if the text matches the regex
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:text, _text, _msg}, _context, nil), do: true

  def call({:text, text, _msg}, _context, %Regex{} = regex) do
    String.match?(text, regex)
  end

  def call({:text, text, _msg}, _context, substring) when is_binary(substring) do
    String.contains?(text, substring)
  end

  def call(_update_info, _context, _opts), do: false
end
