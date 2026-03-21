defmodule ExGram.Router.Dispatcher do
  @moduledoc """
  Runtime component responsible for walking the routing tree and dispatching
  updates to the appropriate handler.

  This module is called by the generated `handle/2` function and should not
  be called directly in user code.

  ## Dispatch algorithm

  1. Iterate over top-level scopes in declaration order.
  2. For each scope, evaluate all filters (AND logic, short-circuit on first false).
  3. If filters pass and the scope is a leaf (has a handler), call the handler.
  4. If filters pass and the scope is a branch (has children), recurse into children.
  5. If no scope matches, return the context unchanged (no-op).
  """

  alias ExGram.Router.Scope

  @doc """
  Dispatches an update to the first matching handler in the routing tree.

  Returns the context (potentially modified by the handler), or the original
  context unchanged if no handler matches.
  """
  @spec dispatch(term(), ExGram.Cnt.t(), [Scope.t()]) :: ExGram.Cnt.t()
  def dispatch(update_info, context, scopes) do
    case match_scopes(update_info, context, scopes) do
      {:ok, updated_context} ->
        updated_context

      :no_match ->
        context
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp match_scopes(update_info, context, scopes) do
    Enum.reduce_while(scopes, :no_match, fn scope, _acc ->
      case match_scope(update_info, context, scope) do
        {:ok, updated_context} -> {:halt, {:ok, updated_context}}
        :no_match -> {:cont, :no_match}
      end
    end)
  end

  defp match_scope(update_info, context, %Scope{} = scope) do
    if all_filters_pass?(update_info, context, scope.filters) do
      case scope.children do
        [] ->
          # Leaf: invoke handler
          {:ok, call_handler(update_info, context, scope.handler)}

        children ->
          # Branch: recurse into children
          match_scopes(update_info, context, children)
      end
    else
      :no_match
    end
  end

  defp all_filters_pass?(_update_info, _context, []), do: true

  defp all_filters_pass?(update_info, context, [{module, opts} | rest]) do
    if module.call(update_info, context, opts) do
      all_filters_pass?(update_info, context, rest)
    else
      false
    end
  end

  defp call_handler(_update_info, context, {mod, fun, 1}) do
    apply(mod, fun, [context])
  end

  defp call_handler(update_info, context, {mod, fun, 2}) do
    apply(mod, fun, [update_info, context])
  end
end
