# Changelog

## [Unreleased]

## [v0.1.0]

### Added

- Declarative routing DSL with `scope`, `filter`, and `handle` macros
- Built-in filters: `:command`, `:text`, `:callback_query`, `:inline_query`, `:regex`, `:message`, `:location`
- Media-type filters: `:photo`, `:audio`, `:document`, `:video`, `:sticker`, `:voice`, `:video_note`, `:animation`, `:contact`, `:poll`
- `ExGram.Router.Filter` behaviour for custom filter modules
- `alias_filter` macro for registering shorthand atoms for custom filters
- State-gated scopes enabling multi-step conversation flows
- Nested scopes for composable routing trees
- `ExGram.Router.__exgram_routing_tree__/0` introspection function
- Mix task `mix ex_gram.router.tree` for visualising the compiled routing tree
- Mix task `mix ex_gram.router.flat` for a flat, one-line-per-handler route listing
