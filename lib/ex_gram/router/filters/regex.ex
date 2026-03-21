defmodule ExGram.Router.Filters.Regex do
  @moduledoc """
  Built-in filter that matches text messages against a compiled regex.

  This is similar to `ExGram.Router.Filters.Text` with a regex option, but
  is the underlying filter used when ExGram dispatches a `:regex` update
  (i.e., when the bot module has declared a `regex/2` pattern and ExGram
  recognizes the text as matching it).

  ## Usage

      # Match a named regex update (declared via ExGram.Bot's regex/2 macro)
      filter ExGram.Router.Filters.Regex, :email

      # Match any regex update
      filter ExGram.Router.Filters.Regex

  ## Options

  - `nil` — matches any `:regex` update
  - `atom` — matches if the regex name equals the given atom
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:regex, _name, _msg}, _context, nil), do: true
  def call({:regex, name, _msg}, _context, expected_name) when name == expected_name, do: true
  def call(_update_info, _context, _opts), do: false
end
