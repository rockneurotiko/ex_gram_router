# ExGram.Router

[![CI](https://github.com/rockneurotiko/ex_gram_router/actions/workflows/ci.yml/badge.svg)](https://github.com/rockneurotiko/ex_gram_router/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/ex_gram_router.svg)](https://hex.pm/packages/ex_gram_router)
[![HexDocs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ex_gram_router/)
[![Hex Downloads](https://img.shields.io/hexpm/dt/ex_gram_router.svg)](https://hex.pm/packages/ex_gram_router)

A declarative routing DSL for [ExGram](https://github.com/rockneurotiko/ex_gram) bots.

`ExGram.Router` replaces hand-written `handle/2` pattern-match clauses with a
composable `scope`/`filter`/`handle` DSL where **everything is a filter** —
built-in filters cover the common update types (commands, text, callback
queries, inline queries, locations) and you can write custom filters to encode
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
- [Handler Arities](#handler-arities)
- [Custom Filters](#custom-filters)
- [Nested Scopes and State Machines](#nested-scopes-and-state-machines)
- [Testing](#testing)
- [Introspection](#introspection)

---

## Installation

Add `ex_gram_router` to your dependencies:

```elixir
# mix.exs
def deps do
  [
    {:ex_gram, "~> 0.60"},
    {:ex_gram_router, "~> 0.1.0"},
    {:jason, ">= 1.0.0"},
    {:req, "~> 0.5"}
  ]
end
```

Configure ExGram in `config/config.exs`:

```elixir
config :ex_gram, adapter: ExGram.Adapter.Req
config :ex_gram, token: System.fetch_env!("BOT_TOKEN")
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

Start ExGram and your bot in your supervision tree:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    token = Application.fetch_env!(:ex_gram, :token)

    children = [
      ExGram,
      {MyApp.Bot, [method: :polling, token: token]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
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
filter :text, "keyword"            # text containing substring
filter :text, ~r/^\d+$/            # text matching regex
filter :callback_query, "action_a" # exact callback data
filter :callback_query, ~r/^page_/ # callback data matching regex

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

| Alias             | Matches                  | Options                                                   |
|-------------------|--------------------------|-----------------------------------------------------------|
| `:command`        | `{:command, name, msg}`  | `nil` (any), atom/string (specific command name)          |
| `:text`           | `{:text, text, msg}`     | `nil` (any), string (substring), `%Regex{}` (regex)      |
| `:callback_query` | `{:callback_query, cq}`  | `nil` (any), string (exact data), `%Regex{}` (regex)     |
| `:inline_query`   | `{:inline_query, iq}`    | `nil` (any), string (exact query), `%Regex{}` (regex)    |
| `:regex`          | `{:regex, name, msg}`    | `nil` (any), atom (specific named regex)                  |
| `:message`        | `{:message, msg}`        | `nil` only (matches any message-type update)              |
| `:location`       | `{:location, loc}`       | `nil` only (matches any location update)                  |

### Examples

```elixir
# Any command
filter :command

# Specific command
filter :command, :start
filter :command, :help

# Any text message
filter :text

# Text containing a word
filter :text, "hello"

# Text matching a pattern
filter :text, ~r/\A\d{4}\z/

# Any callback query
filter :callback_query

# Callback query with exact data
filter :callback_query, "confirm"
filter :callback_query, "cancel"

# Callback query matching a prefix
filter :callback_query, ~r/^page_\d+$/

# Any inline query
filter :inline_query

# Any location update
filter :location

# Any message-type update (photos, documents, stickers, etc.)
filter :message
```

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

## Custom Filters

Implement the `ExGram.Router.Filter` behaviour:

```elixir
@callback call(update_info :: tuple(), context :: ExGram.Cnt.t(), opts :: term()) :: boolean()
```

`call/3` returns `true` to pass (scope matches) or `false` to fail (skip scope).

### Example: Role-based filter

```elixir
defmodule MyApp.Filters.Role do
  @behaviour ExGram.Router.Filter

  @impl ExGram.Router.Filter
  def call(_update_info, context, required_role) do
    {:ok, user} = ExGram.Dsl.extract_user(context)
    MyApp.Accounts.get_role(user.id) == required_role
  end
end
```

Register the alias and use it:

```elixir
defmodule MyApp.Bot do
  use ExGram.Bot, name: :my_bot
  use ExGram.Router

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

This makes it natural to model multi-step conversation flows:

```elixir
defmodule MyApp.Bot do
  use ExGram.Bot, name: :my_bot
  use ExGram.Router

  alias_filter MyApp.Filters.State, as: :state

  command("start",  description: "Start")
  command("cancel", description: "Cancel")

  # /start is always available
  scope do
    filter :command, :start
    handle &MyApp.Handlers.start/1
  end

  # Registration flow — only active when state == :registration
  scope do
    filter :state, :registration

    # Step 1: waiting for name
    scope do
      filter :text
      filter :state, {:sub_state, :get_name}
      handle &MyApp.Handlers.got_name/1
    end

    # Step 2: waiting for email
    scope do
      filter :text
      filter :state, {:sub_state, :get_email}
      handle &MyApp.Handlers.got_email/1
    end

    # Cancel is available at any registration step
    scope do
      filter :command, :cancel
      handle &MyApp.Handlers.cancel/1
    end
  end

  # Ordering flow
  scope do
    filter :state, :ordering

    scope do
      filter :callback_query, ~r/^item_\d+$/
      handle &MyApp.Handlers.item_selected/2
    end

    scope do
      filter :callback_query, "checkout"
      handle &MyApp.Handlers.checkout/1
    end
  end

  # Global fallback
  scope do
    handle &MyApp.Handlers.fallback/1
  end
end
```

**Dispatch rules:**

1. Top-level scopes are tried in declaration order.
2. When a branch scope's filters all pass, its children are tried in order.
3. The first leaf scope whose filters all pass wins.
4. If no scope matches, the update is silently dropped (add a no-filter fallback to handle this).

---

## Testing

`ExGram.Router` works naturally with ExGram's built-in test adapter. No special
setup is required beyond what ExGram already needs.

### Configuration

```elixir
# config/test.exs
config :ex_gram, adapter: ExGram.Adapter.Test
```

```elixir
# config/config.exs — make sure test config is loaded
import Config

# ... other config ...

if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
```

### Test Setup

```elixir
defmodule MyApp.BotTest do
  use ExUnit.Case, async: false
  use ExGram.Test

  defp build_message_update(text, chat_id \\ 123) do
    %ExGram.Model.Update{
      update_id: System.unique_integer([:positive]),
      message: %ExGram.Model.Message{
        message_id: System.unique_integer([:positive]),
        date: 1_700_000_000,
        from: %ExGram.Model.User{id: 1, is_bot: false, first_name: "Test"},
        chat: %ExGram.Model.Chat{id: chat_id, type: "private"},
        text: text
      }
    }
  end

  setup context do
    ExGram.Test.stub(fn
      :send_message, _body -> {:ok, %{message_id: 1}}
      :get_me, _body       -> {:ok, %{id: 1, is_bot: true, first_name: "Bot"}}
      _action, _body       -> {:ok, %{}}
    end)

    {bot_name, _} = ExGram.Test.start_bot(context, MyApp.Bot)
    {:ok, bot_name: bot_name}
  end

  test "/start sends welcome message", %{bot_name: bot_name} do
    ExGram.Test.expect(:send_message, fn body ->
      assert body[:text] == "Welcome!"
      {:ok, %{message_id: 1}}
    end)

    ExGram.Test.push_update(bot_name, build_message_update("/start"))
  end

  test "unknown text falls back", %{bot_name: bot_name} do
    ExGram.Test.expect(:send_message, fn body ->
      assert body[:text] == "I don't understand that."
      {:ok, %{message_id: 1}}
    end)

    ExGram.Test.push_update(bot_name, build_message_update("hello?"))
  end
end
```

### Testing State-Gated Scopes

Pass `extra_info:` to `ExGram.Test.start_bot/3` to pre-seed `context.extra`:

```elixir
test "routes to got_name handler during registration", context do
  {bot_name, _} = ExGram.Test.start_bot(context, MyApp.Bot,
    extra_info: %{state: :registration, sub_state: :get_name}
  )

  ExGram.Test.expect(:send_message, fn body ->
    assert body[:text] == "Got your name!"
    {:ok, %{message_id: 1}}
  end)

  ExGram.Test.push_update(bot_name, build_message_update("John Doe"))
end
```

---

## Introspection

At compile time, `ExGram.Router` generates a `__exgram_routing_tree__/0`
function that returns the compiled scope tree as a list of `ExGram.Router.Scope`
structs. This is useful for debugging and for writing tests that assert on the
routing structure:

```elixir
iex> MyApp.Bot.__exgram_routing_tree__()
[
  %ExGram.Router.Scope{filters: [{ExGram.Router.Filters.Command, :start}], handler: ...},
  %ExGram.Router.Scope{filters: [{ExGram.Router.Filters.Command, :help}], handler: ...},
  ...
]
```

```elixir
test "routing tree is well-formed" do
  tree = MyApp.Bot.__exgram_routing_tree__()
  assert is_list(tree)
  assert length(tree) > 0
  Enum.each(tree, fn scope -> assert %ExGram.Router.Scope{} = scope end)
end
```

## License

[Beerware](./LICENSE) — do whatever you want with it; if we meet someday and you think it was worth it, buy me a beer.

## Links

- [GitHub](https://github.com/rockneurotiko/ex_gram_router)
- [HexDocs](https://hexdocs.pm/ex_gram_router/)
- [Hex Package](https://hex.pm/packages/ex_gram_router)
- [ExGram](https://github.com/rockneurotiko/ex_gram)
