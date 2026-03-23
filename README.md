# ExGram.Router

[![CI](https://github.com/rockneurotiko/ex_gram_router/actions/workflows/ci.yml/badge.svg)](https://github.com/rockneurotiko/ex_gram_router/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/ex_gram_router.svg)](https://hex.pm/packages/ex_gram_router)
[![HexDocs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ex_gram_router/)
[![Hex Downloads](https://img.shields.io/hexpm/dt/ex_gram_router.svg)](https://hex.pm/packages/ex_gram_router)

A declarative routing DSL for [ExGram](https://github.com/rockneurotiko/ex_gram) bots.

`ExGram.Router` replaces hand-written `handle/2` pattern-match clauses with a
composable `scope`/`filter`/`handle` DSL where **everything is a filter** —
built-in filters cover the common update types (commands, text, callback
queries, inline queries, locations, media messages, and more) and you can write custom filters to encode
any runtime predicate: conversation state, user roles, feature flags, and more.

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [DSL Reference](#dsl-reference)
  - [scope](#scope)
  - [filter](#filter)
  - [handle](#handle)
  - [alias_filter](#alias_filter)
- [Built-in Filters](#built-in-filters)
- [use ExGram.Router Options](#use-exgramrouter-options)
- [Enrich Filters](#enrich-filters)
- [Handler Arities](#handler-arities)
- [Mix Tasks](#mix-tasks)
- [Custom Filters](#custom-filters)
- [Nested Scopes and State Machines](#nested-scopes-and-state-machines)
- [Testing](#testing)

---

## Installation

Add `ex_gram_router` to your dependencies:

```elixir
# mix.exs
def deps do
  [
    {:ex_gram, "~> 0.60"},
    {:ex_gram_router, "~> 0.1.0"}
  ]
end
```

---

## Quick Start

```elixir
defmodule MyApp.Bot do
  use ExGram.Bot, name: :my_bot, setup_commands: true
  use ExGram.Router

  command("start", description: "Start the bot")
  command("help",  description: "Show help")

  scope do
    filter :command, :start
    handle &MyApp.Handlers.start/1
  end

  scope do
    filter :command, :help
    handle &MyApp.Handlers.help/1
  end

  scope do
    filter :text
    handle &MyApp.Handlers.echo/1
  end

  # Catch-all fallback — always include one
  scope do
    handle &MyApp.Handlers.fallback/1
  end
end
```

```elixir
defmodule MyApp.Handlers do
  import ExGram.Dsl

  def start(context), do: answer(context, "Welcome!")
  def help(context),  do: answer(context, "Here is what I can do...")
  def echo(context),  do: answer(context, "You said something!")
  def fallback(context), do: context
end
```

---

## DSL Reference

### `scope`

A scope is a block that groups filters and a handler (or nested scopes).
Scopes are evaluated **top-to-bottom**; the **first matching scope wins**.

```elixir
scope do
  # zero or more filters (AND logic)
  filter :command, :start

  # either a handle (leaf) …
  handle &MyApp.Handlers.start/1
end

scope do
  # … or nested scopes (branch)
  filter :state, :registration

  scope do
    filter :text
    handle &MyApp.Handlers.got_text/1
  end
end
```

**Rules:**

- A scope may contain zero or more `filter` declarations.
- A scope is either a **leaf** (has a `handle`) or a **branch** (has nested `scope` blocks). Never both.
- Filters in the same scope are combined with **AND** logic.
- A scope with no filters acts as a pass-through — every update reaches it.
- Nested scopes inherit their parent's filters: a child only runs if the parent's filters already passed.

---

### `filter`

Declares a filter for the current scope.

```elixir
# Built-in alias, no opts (match any update of that type)
filter :command
filter :text
filter :callback_query

# Built-in alias with opts
filter :command, :start            # specific command
filter :text, "keyword"            # exact text match
filter :text, ~r/^\d+$/            # text matching regex
filter :text, contains: "hello"    # text containing substring
filter :text, prefix: "!"          # text starting with prefix
filter :callback_query, "action_a" # exact callback data
filter :callback_query, ~r/^page_/ # callback data matching regex
filter :callback_query, prefix: "settings:"  # callback data with prefix (useful for parent scopes)

# Module directly (no alias needed)
filter MyApp.Filters.AdminOnly

# Module with opts
filter MyApp.Filters.State, :registration
```

---

### `handle`

Declares the handler for a leaf scope. Accepts a **captured function reference**
(`&Module.function/arity`).

```elixir
# 1-arity: receives (context)
handle &MyApp.Handlers.start/1

# 2-arity: receives (update_info, context)
handle &MyApp.Handlers.echo/2
```

See [Handler Arities](#handler-arities) for details.

---

### `alias_filter`

Registers a shorthand name for a filter module, making it available via the
`:atom` form in `filter` declarations.

```elixir
alias_filter MyApp.Filters.State, as: :state
alias_filter MyApp.Filters.AdminOnly, as: :admin

# Now usable as:
filter :state, :registration
filter :admin
```

`alias_filter` must appear at the top of the module, before any `scope` blocks.

---

## Built-in Filters

The following filter aliases are available in every bot using `ExGram.Router`
without any `alias_filter` declaration:

| Alias             | Matches                  | Options                                                                                         |
|-------------------|--------------------------|-------------------------------------------------------------------------------------------------|
| `:command`        | `{:command, name, msg}`  | `nil` (any), atom/string (specific command name)                                                |
| `:text`           | `{:text, text, msg}`     | `nil` (any), string (exact match), `%Regex{}` (regex), `prefix:`, `suffix:`, `contains:`       |
| `:callback_query` | `{:callback_query, cq}`  | `nil` (any), string (exact data), `%Regex{}` (regex), `prefix:`, `suffix:`, `contains:`; add `propagate: true` to a `prefix:` match to enrich child scopes (see [Enrich Filters](#enrich-filters)) |
| `:inline_query`   | `{:inline_query, iq}`    | `nil` (any), string (exact query), `%Regex{}` (regex), `prefix:`, `suffix:`, `contains:`       |
| `:regex`          | `{:regex, name, msg}`    | `nil` (any), atom (specific named regex)                                                        |
| `:message`        | `{:message, msg}`        | `nil` only (matches any message-type update)                                                    |
| `:location`       | `{:location, loc}`       | `nil` only (matches any location update)                                                        |
| `:animation`      | `{:animation, anim}`     | `nil` only                                                                                      |
| `:audio`          | `{:audio, audio}`        | `nil` only                                                                                      |
| `:contact`        | `{:contact, contact}`    | `nil` only                                                                                      |
| `:document`       | `{:document, doc}`       | `nil` only                                                                                      |
| `:photo`          | `{:photo, photos}`       | `nil` only                                                                                      |
| `:poll`           | `{:poll, poll}`          | `nil` only                                                                                      |
| `:sticker`        | `{:sticker, sticker}`    | `nil` only                                                                                      |
| `:video`          | `{:video, video}`        | `nil` only                                                                                      |
| `:video_note`     | `{:video_note, vnote}`   | `nil` only                                                                                      |
| `:voice`          | `{:voice, voice}`        | `nil` only                                                                                      |

### Examples

```elixir
# Any command
filter :command

# Specific command
filter :command, :start
filter :command, :help

# Any text message
filter :text

# Exact text match
filter :text, "hello"

# Text matching a pattern
filter :text, ~r/\A\d{4}\z/

# Text keyword matchers
filter :text, prefix: "!"
filter :text, suffix: "?"
filter :text, contains: "hello"

# Any callback query
filter :callback_query

# Callback query with exact data
filter :callback_query, "confirm"
filter :callback_query, "cancel"

# Callback query matching a regex
filter :callback_query, ~r/^page_\d+$/

# Callback query keyword matchers — useful for hierarchical callback data
filter :callback_query, prefix: "settings:"
filter :callback_query, suffix: ":confirm"
filter :callback_query, contains: "item"

# Callback query prefix with propagation — child scopes match against the remainder
# "proj:change", "proj:delete", etc. — see Enrich Filters for details
filter :callback_query, prefix: "proj:", propagate: true

# Any inline query
filter :inline_query

# Inline query keyword matchers
filter :inline_query, prefix: "@"

# Any location update
filter :location

# Any message-type update (photos, documents, stickers, etc.)
filter :message

# Media message types
filter :animation
filter :audio
filter :contact
filter :document
filter :photo
filter :poll
filter :sticker
filter :video
filter :video_note
filter :voice
```

---

## `use ExGram.Router` Options

`use ExGram.Router` accepts two optional keyword arguments to customise the alias set available in the module.

### `aliases`

Adds extra filter aliases on top of the builtins. Each key must not conflict with an existing builtin alias name.

```elixir
use ExGram.Router,
  aliases: [
    state: MyApp.Filters.State,
    role: MyApp.Filters.Role
  ]
```

After this, `filter :state, :registration` and `filter :role, :admin` work without a separate `alias_filter` call.

### `exclude_aliases`

Removes aliases from the merged set (builtins plus any user-provided `aliases`). Useful when you want to prevent a builtin from being referenced accidentally, or to keep the alias list minimal.

```elixir
use ExGram.Router,
  exclude_aliases: [:poll, :video_note, :animation]
```

### Combined example

```elixir
use ExGram.Router,
  aliases: [state: MyApp.Filters.State],
  exclude_aliases: [:poll, :video_note]
```

---

## Enrich Filters

Filters can optionally implement the `scope_extra/2` callback to **enrich `context.extra` for child scopes** after they pass. This is how a parent scope can pass derived data down to its children without the children having to re-derive it.

```elixir
@callback scope_extra(context :: ExGram.Cnt.t(), opts :: term()) :: map()
```

`scope_extra/2` is called by the dispatcher right after `call/3` returns `true`. The map it returns is merged into `context.extra` via `Map.merge/2` before the dispatcher recurses into child scopes. Sibling scopes always receive the original, un-enriched context — isolation is automatic thanks to Elixir's immutable data.

The callback is `@optional_callbacks` — existing filters that do not implement it are completely unaffected.

### Implementing `scope_extra/2`

```elixir
defmodule MyApp.Filters.Project do
  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call(_update_info, context, project_id) do
    Map.get(context.extra, :project_id) == project_id
  end

  # Called after call/3 returns true — child scopes get context.extra.project
  @impl ExGram.Router.Filter
  def scope_extra(_context, project_id) do
    %{project: MyApp.Projects.get!(project_id)}
  end
end
```

Child scopes then have `context.extra.project` available without any extra lookup:

```elixir
scope do
  filter MyApp.Filters.Project, 42

  scope do
    filter :text
    # context.extra.project is already loaded here
    handle &MyHandlers.handle_text/1
  end
end
```

### Built-in: `:callback_query` with `propagate: true`

The built-in `:callback_query` filter uses `scope_extra/2` to implement **prefix propagation**. When a `prefix:` match includes `propagate: true`, the matched prefix is stored in `context.extra` so that child scopes can match against the remainder of the callback data without repeating it:

```elixir
scope do
  filter :callback_query, prefix: "proj:", propagate: true

  scope do
    filter :callback_query, "change"   # matches "proj:change"
    handle &MyHandlers.change_project/1
  end

  scope do
    filter :callback_query, "delete"   # matches "proj:delete"
    handle &MyHandlers.delete_project/1
  end
end
```

Propagation stacks: a child scope can itself propagate, accumulating prefixes across nesting levels:

```elixir
scope do
  filter :callback_query, prefix: "proj:", propagate: true

  scope do
    filter :callback_query, prefix: "settings:", propagate: true

    scope do
      filter :callback_query, "volume"   # matches "proj:settings:volume"
      handle &MyHandlers.volume/1
    end
  end
end
```

The `mix ex_gram.router.tree` task marks propagating filters with a `[propagate]` indicator; `mix ex_gram.router.flat` includes them in each leaf's full filter chain.

---

## Handler Arities

Handlers can be either 1-arity or 2-arity. The router detects the arity of the
captured function at compile time and dispatches accordingly.

### 1-arity `&Mod.fun/1`

Receives only the `ExGram.Cnt.t()` context. Use when you do not need to inspect
the parsed update tuple.

```elixir
def start(context) do
  answer(context, "Welcome!")
end
```

### 2-arity `&Mod.fun/2`

Receives `(update_info, context)` where `update_info` is the full parsed update
tuple that ExGram dispatches (e.g. `{:command, :echo, msg}`). Use when you need
to extract data from the update directly.

```elixir
# /echo hello world  →  msg.text == "hello world"
def echo({:command, _name, %{text: text}}, context) do
  answer(context, text)
end
```

---

## Mix Tasks

`ExGram.Router` ships with two Mix tasks for inspecting any bot module's routing
configuration. Both tasks compile the project first and call
`__exgram_routing_tree__/0`, which is generated at compile time.

### `mix ex_gram.router.tree`

Prints the routing tree in an indented, hierarchical format. Useful for
understanding the full scope structure and nesting at a glance.

```
mix ex_gram.router.tree MyApp.Bot
```

Example output:

```
MyApp.Bot routing tree:
├── scope
│   ├── filters: [Command(:start)]
│   └── handle: &MyApp.Handlers.start/1
├── scope
│   ├── filters: [Command(:help)]
│   └── handle: &MyApp.Handlers.help/1
└── scope
    ├── filters: [CallbackQuery([prefix: "proj:"]) [propagate]]
    ├── scope
    │   ├── filters: [CallbackQuery("change")]
    │   └── handle: &MyApp.Handlers.change_project/1
    └── scope
        ├── filters: [CallbackQuery("delete")]
        └── handle: &MyApp.Handlers.delete_project/1
```

### `mix ex_gram.router.flat`

Prints a flat, one-line-per-handler listing. Every entry is a leaf with its
full accumulated filter chain - parent scope filters are prepended so you can
see the complete set of conditions that must pass for each handler to run.
Similar to `phx.routes` in Phoenix.

```
mix ex_gram.router.flat MyApp.Bot
```

Example output:

```
MyApp.Bot handlers:
MyApp.Handlers  start/1          filters: [Command(:start)]
MyApp.Handlers  help/1           filters: [Command(:help)]
MyApp.Handlers  change_project/1 filters: [CallbackQuery([prefix: "proj:"]) [propagate], CallbackQuery("change")]
MyApp.Handlers  delete_project/1 filters: [CallbackQuery([prefix: "proj:"]) [propagate], CallbackQuery("delete")]
MyApp.Handlers  fallback/1       filters: []
```

---

## Custom Filters

Implement the `ExGram.Router.Filter` behaviour:

```elixir
@callback call(update_info :: tuple(), context :: ExGram.Cnt.t(), opts :: term()) :: boolean()
```

`call/3` returns `true` to pass (scope matches) or `false` to fail (skip scope). Optionally, implement `scope_extra/2` to enrich `context.extra` for child scopes — see [Enrich Filters](#enrich-filters).

**Filters must be pure.** They are called on every matching update, potentially
many times as the router walks the scope tree, and their result must depend only
on the data already present in `update_info` and `context`. Never perform
database queries, HTTP calls, or other side effects inside a filter — doing so
couples routing decisions to I/O latency and makes the router unpredictable
under load. If a filter needs external data (user role, feature flag, account
status), load it once in a middleware before the router runs and store the result
in `context.extra`. The filter then reads the pre-loaded value cheaply.

### Example: Role-based filter

Filters should not perform I/O (database or HTTP calls). Instead, load the user
role in a middleware and store it in `context.extra`. The filter then reads the
pre-loaded value:

```elixir
defmodule MyApp.Middleware.LoadRole do
  use ExGram.Middleware

  def call(context, _opts) do
    case ExGram.Dsl.extract_user(context) do
      {:ok, user} ->
        role = MyApp.Accounts.get_role(user.id)
        add_extra(context, %{role: role})

      :error ->
        context
    end
  end
end
```

```elixir
defmodule MyApp.Filters.Role do
  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call(_update_info, context, required_role) do
    Map.get(context.extra, :role) == required_role
  end
end
```

Register the middleware and the alias, then use the filter:

```elixir
defmodule MyApp.Bot do
  use ExGram.Bot, name: :my_bot
  use ExGram.Router

  middleware MyApp.Middleware.LoadRole
  alias_filter MyApp.Filters.Role, as: :role

  scope do
    filter :role, :admin
    handle &MyApp.AdminHandlers.panel/1
  end
end
```

### Example: Conversation state filter

A common pattern is to store conversation state in `context.extra` via a
middleware and then route based on it:

```elixir
defmodule MyApp.Filters.State do
  @behaviour ExGram.Router.Filter

  # Match top-level state: filter :state, :registration
  @impl ExGram.Router.Filter
  def call(_update_info, context, expected_state) when is_atom(expected_state) do
    Map.get(context.extra, :state) == expected_state
  end

  # Match a nested key: filter :state, {:sub_state, :get_name}
  def call(_update_info, context, {key, expected_value}) do
    Map.get(context.extra, key) == expected_value
  end
end
```

---

## Nested Scopes and State Machines

Scopes can be arbitrarily nested. A nested scope only runs if its parent's
filters have already passed, so parent filters act as guards for all children.

This makes it natural to model multi-step conversation flows. The recommended
way to manage conversation state is [ExGram.FSM](https://github.com/rockneurotiko/ex_gram_fsm),
a companion library that provides finite state machine flows with pluggable
storage backends. When both libraries are used together, `ExGram.FSM`
automatically registers `:fsm_flow` and `:fsm_state` filter aliases.

### Setup

Add `ex_gram_fsm` alongside `ex_gram_router` in `mix.exs`:

```elixir
def deps do
  [
    {:ex_gram, "~> 0.60"},
    {:ex_gram_router, "~> 0.1.0"},
    {:ex_gram_fsm, "~> 0.1.0"},
    {:jason, ">= 1.0.0"},
    {:req, "~> 0.5"}
  ]
end
```

### Define a flow

Each conversation flow is a separate module:

```elixir
defmodule MyApp.RegistrationFlow do
  use ExGram.FSM.Flow, name: :registration

  defstates do
    state :get_name,  to: [:get_email]
    state :get_email, to: [:done]
    state :done,      to: []
  end

  def default_state, do: :get_name
end
```

### Wire it into the bot

`use ExGram.Router` before `use ExGram.FSM`. The `:fsm_flow` and `:fsm_state`
filter aliases are registered automatically.

```elixir
defmodule MyApp.Bot do
  use ExGram.Bot, name: :my_bot, setup_commands: true
  use ExGram.Router
  use ExGram.FSM,
    storage: ExGram.FSM.Storage.ETS,
    flows: [MyApp.RegistrationFlow]

  command("register", description: "Start registration")

  scope do
    filter :command, :register
    handle &MyApp.Handlers.start_registration/1
  end

  # Route by flow, then by step within the flow
  scope do
    filter :fsm_flow, :registration

    scope do
      filter :fsm_state, :get_name
      filter :text
      handle &MyApp.Handlers.got_name/1
    end

    scope do
      filter :fsm_state, :get_email
      filter :text
      handle &MyApp.Handlers.got_email/1
    end
  end

  scope do
    handle &MyApp.Handlers.fallback/1
  end
end
```

### Handlers

```elixir
defmodule MyApp.Handlers do
  import ExGram.Dsl

  def start_registration(context) do
    context
    |> start_flow(:registration)
    |> answer("What's your name?")
  end

  def got_name(context) do
    name = context.update.message.text

    context
    |> update_data(%{name: name})
    |> transition(:get_email)
    |> answer("Got it, #{name}! What's your email?")
  end

  def got_email(context) do
    %{name: name} = get_data(context)
    email = context.update.message.text

    context
    |> update_data(%{email: email})
    |> clear_flow()
    |> answer("Done! Welcome, #{name} (#{email}).")
  end

  def fallback(context), do: context
end
```

**Dispatch rules:**

1. Top-level scopes are tried in declaration order.
2. When a branch scope's filters all pass, its children are tried in order.
3. The first leaf scope whose filters all pass wins.
4. If no scope matches, the update is silently dropped (add a no-filter fallback to handle this).

---

## Testing

`ExGram.Router` requires no special testing setup. Since the router generates a
standard `handle/2` function, your bot works exactly like any other ExGram bot
in tests — use `ExGram.Adapter.Test`, push updates, and assert on outgoing API
calls as usual.

See the [ExGram testing documentation](https://hexdocs.pm/ex_gram/testing.html)
for full setup instructions.

---

## License

[Beerware](./LICENSE) — do whatever you want with it; if we meet someday and you think it was worth it, buy me a beer.

## Links

- [GitHub](https://github.com/rockneurotiko/ex_gram_router)
- [HexDocs](https://hexdocs.pm/ex_gram_router/)
- [Hex Package](https://hex.pm/packages/ex_gram_router)
- [ExGram](https://github.com/rockneurotiko/ex_gram)
