defmodule Mix.Tasks.ExGram.Router.Flat do
  @shortdoc "Print a flat route listing of an ExGram.Router bot module"

  @moduledoc """
  Prints a flat, one-line-per-handler listing of all routes in an
  `ExGram.Router` bot module. Unlike the tree view, every entry is a leaf
  with its full accumulated filter chain (parent scope filters are prepended).

  ## Usage

      mix ex_gram.router.flat MyApp.Bot

  ## Example output

      MyApp.Bot handlers:
      MyHandlers    start/1    filters: [Command(:start)]
      Handlers      got_name/2 filters: [State(:registration), Text, State(:get_name)]
      Handlers      got_email/1 filters: [State(:registration), Text, State(:get_email)]
      Handlers      fallback/1 filters: []

  The module must `use ExGram.Router` - it must export `__exgram_routing_tree__/0`.
  """

  use Mix.Task

  alias Mix.Tasks.ExGram.Router.FormatHelpers

  @impl Mix.Task
  def run([]) do
    Mix.shell().error("""
    Usage: mix ex_gram.router.flat <ModuleName>

    Example:
        mix ex_gram.router.flat MyApp.Bot
    """)

    Mix.raise("Module name argument is required.")
  end

  def run([module_string | _rest]) do
    Mix.Task.run("compile")

    module = Module.concat([module_string])

    if not Code.ensure_loaded?(module) do
      Mix.raise("Module #{inspect(module)} could not be loaded. Is it compiled?")
    end

    if not function_exported?(module, :__exgram_routing_tree__, 0) do
      Mix.raise(
        "Module #{inspect(module)} does not appear to be an ExGram.Router module. " <>
          "It does not export __exgram_routing_tree__/0."
      )
    end

    tree = module.__exgram_routing_tree__()
    routes = flatten_scopes(tree, [])

    Mix.shell().info("#{module_string} handlers:")
    print_routes(routes)
  end

  # ---------------------------------------------------------------------------
  # Private - tree flattening
  # ---------------------------------------------------------------------------

  defp flatten_scopes(scopes, parent_filters) do
    Enum.flat_map(scopes, fn scope ->
      all_filters = parent_filters ++ scope.filters

      case scope.children do
        [] ->
          [{scope.handler, all_filters}]

        children ->
          flatten_scopes(children, all_filters)
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private - rendering
  # ---------------------------------------------------------------------------

  defp print_routes(routes) do
    rows =
      Enum.map(routes, fn {handler, filters} ->
        {mod_str, fun_str} = FormatHelpers.split_handler(handler)
        filters_str = "filters: [#{Enum.map_join(filters, ", ", &FormatHelpers.format_filter/1)}]"
        {mod_str, fun_str, filters_str}
      end)

    mod_width = rows |> Enum.map(fn {m, _, _} -> String.length(m) end) |> Enum.max(fn -> 0 end)
    fun_width = rows |> Enum.map(fn {_, f, _} -> String.length(f) end) |> Enum.max(fn -> 0 end)

    Enum.each(rows, fn {mod_str, fun_str, filters_str} ->
      col1 = String.pad_trailing(mod_str, mod_width)
      col2 = String.pad_trailing(fun_str, fun_width)
      Mix.shell().info("#{col1}  #{col2}  #{filters_str}")
    end)
  end
end
