defmodule ExGram.Router.Filter do
  @moduledoc """
  Behaviour for ExGram.Router filters.

  A filter is a module that decides whether a particular scope or handler
  should match a given update. Filters receive the parsed update info tuple
  (the same first argument ExGram passes to `handle/2`), the full context,
  and any opts provided in the `filter` declaration.

  ## Example

      defmodule MyApp.Filters.AdminOnly do
        @behaviour ExGram.Router.Filter

        def call(_update_info, context, _opts) do
          {:ok, user} = ExGram.Dsl.extract_user(context)
          user.id in Application.fetch_env!(:my_app, :admin_ids)
        end
      end

  ## Usage

      scope do
        filter MyApp.Filters.AdminOnly
        handle &MyBot.admin_panel/1
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
end
