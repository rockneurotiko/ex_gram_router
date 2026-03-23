defmodule Mix.Tasks.ExGram.Router.FormatHelpers do
  @moduledoc false

  @doc """
  Formats a `{module, opts}` filter tuple as a human-readable string.

  Uses the filter module's `format_filter/1` callback when available,
  falling back to a generic representation otherwise.
  """
  def format_filter({module, opts}) do
    Code.ensure_loaded!(module)

    if function_exported?(module, :format_filter, 1) do
      module.format_filter(opts)
    else
      default_format_filter(module, opts)
    end
  end

  @doc """
  Formats a `{module, fun, arity}` handler tuple as `&Module.function/arity`.
  """
  def format_handler({mod, fun, arity}) do
    "&#{inspect(mod)}.#{fun}/#{arity}"
  end

  @doc """
  Splits a `{module, fun, arity}` handler tuple into `{module_string, fun_arity_string}`.

  Useful for rendering handlers in two separate columns.

  ## Examples

      iex> split_handler({MyApp.Handlers, :start, 1})
      {"MyApp.Handlers", "start/1"}
  """
  def split_handler({mod, fun, arity}) do
    {inspect(mod), "#{fun}/#{arity}"}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp default_format_filter(module, nil), do: short_name(module)
  defp default_format_filter(module, opts), do: "#{short_name(module)}(#{inspect(opts)})"

  defp short_name(module) do
    module
    |> Module.split()
    |> List.last()
  end
end
