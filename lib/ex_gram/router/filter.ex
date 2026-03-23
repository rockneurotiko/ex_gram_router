defmodule ExGram.Router.Filter do
  @moduledoc """
  Behaviour for ExGram.Router filters.

  A filter is a module that decides whether a particular scope or handler
  should match a given update. Filters receive the parsed update info tuple
  (the same first argument ExGram passes to `handle/2`), the full context,
  and any opts provided in the `filter` declaration.

  ## Callbacks

  ### `call/3` (required)

  Returns `true` if the filter passes (the scope should be considered) or
  `false` if it fails (skip this scope).

  ### `scope_extra/2` (optional)

  Called by the dispatcher **after** `call/3` returns `true`, only when the
  filter implements this callback. Returns a map that is merged into
  `context.extra` before recursing into child scopes. This lets a filter
  enrich the context for its children without affecting sibling scopes.

  Because Elixir data is immutable, enrichment is automatically isolated:
  siblings receive the original context from their parent's caller, not the
  enriched copy.

  ## Example – basic filter

      defmodule MyApp.Filters.AdminOnly do
        @behaviour ExGram.Router.Filter

        def call(_update_info, context, _opts) do
          {:ok, user} = ExGram.Dsl.extract_user(context)
          user.id in Application.fetch_env!(:my_app, :admin_ids)
        end
      end

      scope do
        filter MyApp.Filters.AdminOnly
        handle &MyBot.admin_panel/1
      end

  ## Example – filter with propagation via `scope_extra/2`

  The built-in `:callback_query` filter implements `scope_extra/2` and
  supports the `propagate: true` option. When a parent scope sets
  `propagate: true`, child scopes see an accumulated prefix in
  `context.extra.__exgram_router__.text_prefix` so they can match against
  the suffix of the callback data:

      scope do
        filter :callback_query, prefix: "proj:", propagate: true

        scope do
          filter :callback_query, "change"   # matches "proj:change"
          handle &Handlers.change_project/1
        end
      end
  """

  @type update_info :: tuple() | atom()
  @type context :: ExGram.Cnt.t()
  @type opts :: term()

  @doc """
  Determines whether the current update matches this filter.

  Returns `true` if the filter passes (the handler should be considered),
  or `false` if the filter fails (skip this scope/handler).
  """
  @callback call(update_info(), context(), opts()) :: boolean()

  @doc """
  Optionally enriches `context.extra` for child scopes after this filter passes.

  Returns a map that will be merged (via `Map.merge/2`) into `context.extra`
  before the dispatcher recurses into child scopes. Returning an empty map
  `%{}` has no effect.

  The `update_info` is intentionally **not** provided — enrichment should be
  driven by opts and any accumulated state already present in `context.extra`.

  This callback is optional. Filters that do not need to enrich context can
  omit it entirely.
  """
  @callback scope_extra(context(), opts()) :: map()

  @doc """
  Formats this filter as a human-readable string for display in the routing tree.

  Called by `mix ex_gram.router.tree` when rendering a scope's filter list.
  The returned string is used directly in the tree output - it should include
  the filter name and any relevant opts representation.

  This callback is optional. Filters that do not implement it fall back to
  the default generic formatting provided by the mix task.

  ## Example

      # For `filter :command, :start` the default output is:
      #   Command(:start)

      # A filter that formats itself:
      def format_filter(nil), do: "MyFilter"
      def format_filter(opts), do: "MyFilter(\#{inspect(opts)})"
  """
  @callback format_filter(opts()) :: String.t()

  @optional_callbacks [scope_extra: 2, format_filter: 1]

  # ---------------------------------------------------------------------------
  # Shared text-matching helper (used by text and callback_query filters)
  # ---------------------------------------------------------------------------

  @doc """
  Matches `text` against `match`, optionally using accumulated prefix from `context`.

  When `context.extra.__exgram_router__.text_prefix` is set (e.g., by a parent
  scope's `:callback_query` filter with `propagate: true`), the accumulated
  prefix is prepended to the match target before comparison. This allows child
  scopes to express matches relative to the prefix already consumed by an ancestor.

  ## Match forms

  - `%Regex{}` — regex match against the full text (prefix is **not** prepended for
    regex matches, since regexes are inherently absolute)
  - `binary` — exact equality after prepending accumulated prefix
  - `keyword list` — one of:
    - `prefix: string` — text starts with `(accumulated_prefix <> prefix)`
    - `suffix: string` — text ends with the suffix (accumulated prefix is not used)
    - `contains: string` — text contains the substring (accumulated prefix is not used)
  """
  @spec text_filter(String.t(), term(), context() | nil) :: boolean()
  def text_filter(text, match, context \\ nil)

  def text_filter(text, %Regex{} = regex, _context) when is_binary(text) do
    String.match?(text, regex)
  end

  def text_filter(text, match, context) when is_binary(text) and is_binary(match) do
    full_match = accumulated_prefix(context) <> match
    text == full_match
  end

  def text_filter(text, opts, context) when is_binary(text) and is_list(opts) do
    prefix = accumulated_prefix(context)

    cond do
      target = opts[:prefix] -> String.starts_with?(text, prefix <> target)
      suffix = opts[:suffix] -> String.ends_with?(text, suffix)
      contains = opts[:contains] -> String.contains?(text, contains)
      true -> false
    end
  end

  def text_filter(_text, _match, _context), do: false

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp accumulated_prefix(nil), do: ""

  defp accumulated_prefix(context) do
    get_in(context.extra, [:__exgram_router__, :text_prefix]) || ""
  end
end
