defmodule ExGram.Router.Filters.Command do
  @moduledoc """
  Built-in filter that matches Telegram command updates.

  ## Usage

      # Match any command
      filter ExGram.Router.Filters.Command

      # Match a specific command
      filter ExGram.Router.Filters.Command, :start

      # Or using the built-in alias
      filter :command, :start
      filter :command  # matches any command

  ## Options

  - `nil` — matches any command update
  - `atom` — matches a specific declared command (e.g., `:start`)
  - `string` — matches an undeclared command string (e.g., `"unknown_cmd"`)
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:command, _name, _msg}, _context, nil), do: true
  def call({:command, name, _msg}, _context, expected) when name == expected, do: true
  def call(_update_info, _context, _opts), do: false
end
