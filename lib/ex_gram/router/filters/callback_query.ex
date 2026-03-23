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

  ## Prefix propagation

  When matching with a `prefix:` option, you can add `propagate: true` to
  automatically strip the consumed prefix for all child scopes. Child scopes
  can then match using the remainder of the callback data, without repeating
  the parent's prefix.

      scope do
        filter :callback_query, prefix: "proj:", propagate: true

        scope do
          # Matches "proj:change" — the prefix is prepended automatically
          filter :callback_query, "change"
          handle &Handlers.change_project/1
        end

        scope do
          # Nested propagation: matches "proj:settings:volume"
          filter :callback_query, prefix: "settings:", propagate: true

          scope do
            filter :callback_query, "volume"
            handle &Handlers.volume/1
          end
        end
      end

  The propagation works by writing the accumulated prefix into
  `context.extra.__exgram_router__.text_prefix`. This only affects child
  scopes — sibling scopes always receive the original context.
  """

  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call({:callback_query, _cq}, _context, nil), do: true

  def call({:callback_query, %{data: data}}, context, match) do
    ExGram.Router.Filter.text_filter(data, match, context)
  end

  def call(_update_info, _context, _opts), do: false

  @impl ExGram.Router.Filter
  def scope_extra(context, opts) when is_list(opts) do
    if opts[:propagate] do
      existing = get_in(context.extra, [:__exgram_router__, :text_prefix]) || ""
      new_prefix = existing <> (opts[:prefix] || "")
      %{__exgram_router__: %{text_prefix: new_prefix}}
    else
      %{}
    end
  end

  def scope_extra(_context, _opts), do: %{}

  @impl ExGram.Router.Filter
  def format_filter(nil), do: "CallbackQuery"

  def format_filter(opts) when is_list(opts) do
    if Keyword.get(opts, :propagate, false) do
      clean_opts = Keyword.delete(opts, :propagate)

      base =
        if clean_opts == [],
          do: "CallbackQuery",
          else: "CallbackQuery(#{inspect(clean_opts)})"

      base <> " [propagate]"
    else
      "CallbackQuery(#{inspect(opts)})"
    end
  end

  def format_filter(opts), do: "CallbackQuery(#{inspect(opts)})"
end
