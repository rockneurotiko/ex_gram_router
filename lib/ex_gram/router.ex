defmodule ExGram.Router do
  @moduledoc """
  A declarative routing DSL for ExGram bots.

  `ExGram.Router` provides a `scope`/`filter`/`handle` DSL that replaces
  writing individual `handle/2` clause pattern-matches by hand. Everything
  is a filter: built-in filters cover the common update types (commands, text,
  callback queries, etc.) and custom filters can encode arbitrary runtime
  predicates (e.g., checking conversation state, user roles).

  ## Usage

      defmodule MyBot do
        use ExGram.Bot, name: :my_bot
        use ExGram.Router

        # Alias custom filters for convenience (optional)
        alias_filter MyApp.Filters.State, as: :state

        # /start command
        scope do
          filter :command, :start
          handle &MyBot.Handlers.start/1
        end

        # Registration flow (state-gated)
        scope do
          filter :state, :registration

          scope do
            filter :text
            filter :state, :get_name
            handle &MyBot.Handlers.get_name/2
          end

          scope do
            filter :text
            filter :state, :get_email
            handle &MyBot.Handlers.get_email/1
          end

          # Admin sub-scope within registration
          scope do
            filter MyBot.Filters.AdminCheck
            filter :command, :admin
            handle &MyBot.Handlers.admin_cmd/2
          end
        end

        # Fallback: no filters = matches everything
        scope do
          handle &MyBot.Handlers.fallback/1
        end
      end

  ## Scope rules

  A scope can contain:
  - Zero or more `filter` declarations (evaluated in order with AND logic)
  - Either a `handle` (leaf scope) OR nested `scope` blocks (branch scope), not both
  - A scope with no filters acts as a pass-through (all updates reach it)

  ## Built-in filter aliases

  The following aliases are available without `alias_filter`:

  | Alias              | Module                                    | Example usage                         |
  |--------------------|-------------------------------------------|---------------------------------------|
  | `:command`         | `ExGram.Router.Filters.Command`           | `filter :command, :start`             |
  | `:text`            | `ExGram.Router.Filters.Text`              | `filter :text`                        |
  | `:callback_query`  | `ExGram.Router.Filters.CallbackQuery`     | `filter :callback_query, "action_a"`  |
  | `:regex`           | `ExGram.Router.Filters.Regex`             | `filter :regex, :email`               |
  | `:message`         | `ExGram.Router.Filters.Message`           | `filter :message`                     |
  | `:inline_query`    | `ExGram.Router.Filters.InlineQuery`       | `filter :inline_query`                |
  | `:location`        | `ExGram.Router.Filters.Location`          | `filter :location`                    |
  | `:animation`       | `ExGram.Router.Filters.Animation`         | `filter :animation`                   |
  | `:audio`           | `ExGram.Router.Filters.Audio`             | `filter :audio`                       |
  | `:contact`         | `ExGram.Router.Filters.Contact`           | `filter :contact`                     |
  | `:document`        | `ExGram.Router.Filters.Document`          | `filter :document`                    |
  | `:photo`           | `ExGram.Router.Filters.Photo`             | `filter :photo`                       |
  | `:poll`            | `ExGram.Router.Filters.Poll`              | `filter :poll`                        |
  | `:sticker`         | `ExGram.Router.Filters.Sticker`           | `filter :sticker`                     |
  | `:video`           | `ExGram.Router.Filters.Video`             | `filter :video`                       |
  | `:video_note`      | `ExGram.Router.Filters.VideoNote`         | `filter :video_note`                  |
  | `:voice`           | `ExGram.Router.Filters.Voice`             | `filter :voice`                       |

  ## `use ExGram.Router` options

  - **`aliases: [atom: Module, ...]`** - Additional filter aliases to merge with the builtins.
    Each key must not conflict with an existing builtin alias.
  - **`exclude_aliases: [:atom, ...]`** - Builtin (or user-provided) aliases to remove from the
    final alias set. Useful when you want to prevent a builtin from being referenced.

  Example:

      use ExGram.Router,
        aliases: [state: MyApp.Filters.State],
        exclude_aliases: [:poll, :video_note]

  ## Custom filters

  Implement the `ExGram.Router.Filter` behaviour:

      defmodule MyApp.Filters.AdminOnly do
        @behaviour ExGram.Router.Filter

        @impl ExGram.Router.Filter
        def call(_update_info, context, _opts) do
          {:ok, user} = ExGram.Dsl.extract_user(context)
          user.id in Application.fetch_env!(:my_app, :admin_ids)
        end
      end

  ## Handler arities

  - **1-arity** `&MyMod.fun/1` — receives only the `ExGram.Cnt.t()` context
  - **2-arity** `&MyMod.fun/2` — receives `(update_info, context)`, where
    `update_info` is the parsed update tuple (e.g. `{:command, :start, msg}`)

  ## `alias_filter` syntax

      alias_filter SomeFilterModule, as: :my_alias

  After this, `filter :my_alias, opts` resolves to `SomeFilterModule.call(update_info, context, opts)`.
  """

  @builtin_aliases [
    command: ExGram.Router.Filters.Command,
    text: ExGram.Router.Filters.Text,
    callback_query: ExGram.Router.Filters.CallbackQuery,
    regex: ExGram.Router.Filters.Regex,
    message: ExGram.Router.Filters.Message,
    inline_query: ExGram.Router.Filters.InlineQuery,
    location: ExGram.Router.Filters.Location,
    animation: ExGram.Router.Filters.Animation,
    audio: ExGram.Router.Filters.Audio,
    contact: ExGram.Router.Filters.Contact,
    document: ExGram.Router.Filters.Document,
    photo: ExGram.Router.Filters.Photo,
    poll: ExGram.Router.Filters.Poll,
    sticker: ExGram.Router.Filters.Sticker,
    video: ExGram.Router.Filters.Video,
    video_note: ExGram.Router.Filters.VideoNote,
    voice: ExGram.Router.Filters.Voice
  ]

  @doc false
  defmacro __using__(opts) do
    user_aliases = Keyword.get(opts, :aliases, [])
    exclude = Keyword.get(opts, :exclude_aliases, [])

    for {alias_key, _mod} <- user_aliases do
      if Keyword.has_key?(@builtin_aliases, alias_key) do
        raise CompileError,
          description: "alias :#{alias_key} conflicts with a builtin alias in ExGram.Router"
      end
    end

    merged = @builtin_aliases ++ user_aliases
    final_aliases = Keyword.drop(merged, exclude)

    quote do
      import ExGram.Router.Dsl, only: [scope: 1, filter: 1, filter: 2, handle: 1, alias_filter: 2]

      # Stack of in-progress scopes during compilation (last = innermost)
      Module.register_attribute(__MODULE__, :__exgram_scope_stack__, accumulate: false)
      Module.put_attribute(__MODULE__, :__exgram_scope_stack__, [])

      # Completed top-level scopes (accumulated in reverse declaration order)
      Module.register_attribute(__MODULE__, :__exgram_scopes__, accumulate: true)

      # User-registered filter aliases (accumulated list of {atom, module})
      Module.register_attribute(__MODULE__, :__exgram_filter_aliases__, accumulate: false)

      # Seed with builtin aliases merged with user-provided aliases, minus any exclusions
      Module.put_attribute(__MODULE__, :__exgram_filter_aliases__, unquote(final_aliases))

      @before_compile ExGram.Router.Compiler
    end
  end
end
