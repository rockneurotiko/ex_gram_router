defmodule ExGram.Router.Dispatcher do
  @moduledoc """
  Runtime component responsible for walking the routing tree and dispatching
  updates to the appropriate handler.

  This module is called by the generated `handle/2` function and should not
  be called directly in user code.

  ## Dispatch algorithm

  1. Iterate over top-level scopes in declaration order.
  2. For each scope, evaluate all filters (AND logic, short-circuit on first false).
  3. After each passing filter, call `scope_extra/2` if implemented — the returned
     map is merged into `context.extra` before proceeding to remaining filters and
     child scopes. Sibling scopes receive the original, un-enriched context.
  4. If all filters pass and the scope is a leaf (has a handler), call the handler
     with the enriched context.
  5. If all filters pass and the scope is a branch (has children), recurse into
     children with the enriched context.
  6. If no scope matches, return the context unchanged (no-op).
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
    case apply_filters(update_info, context, scope.filters) do
      {:pass, enriched_context} ->
        case scope.children do
          [] ->
            # Leaf: invoke handler with enriched context
            {:ok, call_handler(update_info, enriched_context, scope.handler)}

          children ->
            # Branch: recurse into children with enriched context
            match_scopes(update_info, enriched_context, children)
        end

      :no_match ->
        :no_match
    end
  end

  # Iterates filters with AND logic. After each passing filter, calls
  # `scope_extra/2` (if implemented) and merges the result into context.extra.
  # Returns {:pass, enriched_context} or :no_match.
  defp apply_filters(_update_info, context, []) do
    {:pass, context}
  end

  defp apply_filters(update_info, context, [{module, opts} | rest]) do
    if module.call(update_info, context, opts) do
      enriched_context =
        if function_exported?(module, :scope_extra, 2) do
          extra = module.scope_extra(context, opts)
          %{context | extra: Map.merge(context.extra, extra)}
        else
          context
        end

      apply_filters(update_info, enriched_context, rest)
    else
      :no_match
    end
  end

  defp call_handler(_update_info, context, {mod, fun, 1}) do
    apply(mod, fun, [context])
  end

  defp call_handler(update_info, context, {mod, fun, 2}) do
    apply(mod, fun, [update_info, context])
  end
end
