defmodule Mix.Tasks.ExGram.Router.Tree do
  @shortdoc "Print the routing tree of an ExGram.Router bot module"

  @moduledoc """
  Prints the routing tree of an `ExGram.Router` bot module in a human-readable
  indented tree format.

  ## Usage

      mix ex_gram.router.tree MyApp.Bot

  ## Example output

      MyApp.Bot routing tree:
      ├── scope
      │   ├── filters: [Command(:start)]
      │   └── handle: &MyHandlers.start/1
      └── scope
          ├── filters: [StateFilter(:registration)]
          ├── scope
          │   ├── filters: [Text, StateFilter({:sub_state, :get_name})]
          │   └── handle: &Handlers.got_name/1
          └── scope
              ├── filters: [Text, StateFilter({:sub_state, :get_email})]
              └── handle: &Handlers.got_email/1

  The module must `use ExGram.Router` — it must export `__exgram_routing_tree__/0`.
  """

  use Mix.Task

  @impl Mix.Task
  def run([]) do
    Mix.shell().error("""
    Usage: mix ex_gram.router.tree <ModuleName>

    Example:
        mix ex_gram.router.tree MyApp.Bot
    """)

    Mix.raise("Module name argument is required.")
  end

  def run([module_string | _rest]) do
    Mix.Task.run("compile")

    module = Module.concat([module_string])

    if !Code.ensure_loaded?(module) do
      Mix.raise("Module #{inspect(module)} could not be loaded. Is it compiled?")
    end

    if !function_exported?(module, :__exgram_routing_tree__, 0) do
      Mix.raise(
        "Module #{inspect(module)} does not appear to be an ExGram.Router module. " <>
          "It does not export __exgram_routing_tree__/0."
      )
    end

    tree = module.__exgram_routing_tree__()

    Mix.shell().info("#{module_string} routing tree:")
    print_scopes(tree, "")
  end

  # ---------------------------------------------------------------------------
  # Private rendering
  # ---------------------------------------------------------------------------

  defp print_scopes(scopes, indent) do
    total = length(scopes)

    scopes
    |> Enum.with_index(1)
    |> Enum.each(fn {scope, index} ->
      last? = index == total
      print_scope(scope, indent, last?)
    end)
  end

  defp print_scope(scope, indent, last?) do
    branch = if last?, do: "└── ", else: "├── "
    child_indent = if last?, do: indent <> "    ", else: indent <> "│   "

    Mix.shell().info(indent <> branch <> "scope")

    case scope.children do
      [] ->
        # Leaf: print filters (if any) then handler
        lines = build_leaf_lines(scope)
        print_lines(lines, child_indent)

      children ->
        # Branch: print filters (if any), then recurse into children
        filter_lines = build_filter_lines(scope)
        Enum.each(filter_lines, &Mix.shell().info(child_indent <> "├── " <> &1))
        print_scopes(children, child_indent)
    end
  end

  defp print_lines(lines, indent) do
    total = length(lines)

    lines
    |> Enum.with_index(1)
    |> Enum.each(fn {line, idx} ->
      line_branch = if idx == total, do: "└── ", else: "├── "
      Mix.shell().info(indent <> line_branch <> line)
    end)
  end

  defp build_leaf_lines(%ExGram.Router.Scope{} = scope) do
    filter_lines = build_filter_lines(scope)

    handler_line =
      case scope.handler do
        {mod, fun, arity} -> ["handle: &#{inspect(mod)}.#{fun}/#{arity}"]
        nil -> []
      end

    filter_lines ++ handler_line
  end

  defp build_filter_lines(%ExGram.Router.Scope{filters: []}), do: []

  defp build_filter_lines(%ExGram.Router.Scope{filters: filters}) do
    ["filters: [#{Enum.map_join(filters, ", ", &format_filter/1)}]"]
  end

  defp format_filter({module, opts}) do
    if function_exported?(module, :format_filter, 1) do
      module.format_filter(opts)
    else
      default_format_filter(module, opts)
    end
  end

  defp default_format_filter(module, nil), do: short_name(module)
  defp default_format_filter(module, opts), do: "#{short_name(module)}(#{inspect(opts)})"

  defp short_name(module) do
    module
    |> Module.split()
    |> List.last()
  end
end
