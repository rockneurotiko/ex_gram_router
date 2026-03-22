defmodule ExGram.Router.Scope do
  @moduledoc """
  Internal data structure representing a node in the routing tree.

  A scope is either:
  - A **leaf**: has a handler (and optionally filters), no children.
  - A **branch**: has filters and children scopes, no handler.

  Scopes are built at compile time by the DSL macros and stored as a nested
  structure. At runtime, the dispatcher walks this tree top-to-bottom to find
  the first matching handler.
  """

  @type filter :: {module(), term()}
  @type handler :: {module(), atom(), 1 | 2}

  @type t :: %__MODULE__{
          children: [t()],
          filters: [filter()],
          handler: handler() | nil
        }

  defstruct children: [], filters: [], handler: nil

  @doc """
  Returns true if the scope is a leaf node (has a handler and no children).
  """
  def leaf?(%__MODULE__{children: [], handler: handler}) when not is_nil(handler), do: true
  def leaf?(%__MODULE__{}), do: false
end
