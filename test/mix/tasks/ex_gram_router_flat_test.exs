defmodule Mix.Tasks.ExGram.Router.FlatTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  # ---------------------------------------------------------------------------
  # Support modules
  # ---------------------------------------------------------------------------

  defmodule FlatTestHandlers do
    def start(context), do: context
    def help(context), do: context
    def fallback(context), do: context
    def echo(update_info, context), do: {update_info, context}
    def deep(context), do: context
  end

  defmodule FlatTestFilter do
    @behaviour ExGram.Router.Filter

    @impl ExGram.Router.Filter
    def call(_update_info, _context, _opts), do: true
  end

  defmodule FlatTestCustomFormatFilter do
    @behaviour ExGram.Router.Filter

    @impl ExGram.Router.Filter
    def call(_update_info, _context, _opts), do: true

    @impl ExGram.Router.Filter
    def format_filter(nil), do: "CustomFilter"
    def format_filter(opts), do: "CustomFilter<#{inspect(opts)}>"
  end

  defmodule FlatTestBot do
    use ExGram.Bot, name: :flat_test_bot
    use ExGram.Router

    alias_filter(Mix.Tasks.ExGram.Router.FlatTest.FlatTestFilter, as: :flat_test_filter)

    scope do
      filter(:command, :start)
      handle(&Mix.Tasks.ExGram.Router.FlatTest.FlatTestHandlers.start/1)
    end

    scope do
      filter(:command, :help)
      handle(&Mix.Tasks.ExGram.Router.FlatTest.FlatTestHandlers.help/1)
    end

    scope do
      filter(:flat_test_filter, :some_state)

      scope do
        filter(:command, :echo)
        handle(&Mix.Tasks.ExGram.Router.FlatTest.FlatTestHandlers.echo/2)
      end
    end

    scope do
      handle(&Mix.Tasks.ExGram.Router.FlatTest.FlatTestHandlers.fallback/1)
    end
  end

  defmodule FlatTestCustomBot do
    use ExGram.Bot, name: :flat_test_custom_bot
    use ExGram.Router

    alias_filter(
      Mix.Tasks.ExGram.Router.FlatTest.FlatTestCustomFormatFilter,
      as: :custom_format_filter
    )

    scope do
      filter(:custom_format_filter, :some_opts)
      handle(&Mix.Tasks.ExGram.Router.FlatTest.FlatTestHandlers.start/1)
    end

    scope do
      filter(:callback_query, prefix: "proj:", propagate: true)

      scope do
        filter(:callback_query, "change")
        handle(&Mix.Tasks.ExGram.Router.FlatTest.FlatTestHandlers.help/1)
      end
    end
  end

  # Three levels of nesting to test deep filter inheritance
  defmodule FlatTestDeepBot do
    use ExGram.Bot, name: :flat_test_deep_bot
    use ExGram.Router

    alias_filter(Mix.Tasks.ExGram.Router.FlatTest.FlatTestFilter, as: :flat_test_filter)

    scope do
      filter(:flat_test_filter, :level_one)

      scope do
        filter(:flat_test_filter, :level_two)

        scope do
          filter(:flat_test_filter, :level_three)
          handle(&Mix.Tasks.ExGram.Router.FlatTest.FlatTestHandlers.deep/1)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp run_task(module_name) do
    capture_io(fn ->
      Mix.Tasks.ExGram.Router.Flat.run([module_name])
    end)
  end

  # ---------------------------------------------------------------------------
  # Tests: header
  # ---------------------------------------------------------------------------

  describe "run/1 - header" do
    test "prints the module name followed by 'handlers:'" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestBot")
      assert output =~ "FlatTestBot handlers:"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: flat listing
  # ---------------------------------------------------------------------------

  describe "run/1 - flat route listing" do
    test "each handler appears on its own line" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestBot")
      assert output =~ "start/1"
      assert output =~ "help/1"
      assert output =~ "echo/2"
      assert output =~ "fallback/1"
    end

    test "handler module and function are in separate columns" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestBot")
      # Module name appears as its own column, separate from the function
      assert output =~ "Mix.Tasks.ExGram.Router.FlatTest.FlatTestHandlers"
      assert output =~ "start/1"
    end

    test "leaf handler filters are shown inline" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestBot")
      assert output =~ "filters: [Command(:start)]"
      assert output =~ "filters: [Command(:help)]"
    end

    test "handler with no filters shows empty filters list" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestBot")
      assert output =~ "filters: []"
    end

    test "nested handler inherits parent scope filters prepended" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestBot")
      # echo is nested inside flat_test_filter scope - parent filter comes first
      assert output =~ "filters: [FlatTestFilter(:some_state), Command(:echo)]"
    end

    test "does not print branch scope lines (no intermediate scopes)" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestBot")
      refute output =~ "scope"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: deep nesting accumulates all ancestor filters
  # ---------------------------------------------------------------------------

  describe "run/1 - deep nesting" do
    test "three levels of nesting accumulates all ancestor filters in order" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestDeepBot")

      assert output =~
               "filters: [FlatTestFilter(:level_one), FlatTestFilter(:level_two), FlatTestFilter(:level_three)]"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: custom format_filter/1 callback
  # ---------------------------------------------------------------------------

  describe "run/1 - format_filter callback" do
    test "uses the filter module's format_filter/1 when implemented" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestCustomBot")
      assert output =~ "CustomFilter<:some_opts>"
    end

    test "falls back to generic format for filters without format_filter/1" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestBot")
      assert output =~ "Command(:start)"
      assert output =~ "FlatTestFilter(:some_state)"
    end

    test "CallbackQuery with propagate shows [propagate] suffix" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestCustomBot")
      assert output =~ ~s|CallbackQuery([prefix: "proj:"]) [propagate]|
    end

    test "inherited CallbackQuery prefix filter appears in child's filter list" do
      output = run_task("Mix.Tasks.ExGram.Router.FlatTest.FlatTestCustomBot")
      # The help handler is inside the propagate scope - both filters appear
      assert output =~ ~s|CallbackQuery([prefix: "proj:"]) [propagate]|
      assert output =~ ~s|CallbackQuery("change")|
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: error cases
  # ---------------------------------------------------------------------------

  describe "run/1 with no arguments" do
    test "raises Mix.Error with a usage message" do
      assert_raise Mix.Error, fn ->
        capture_io(fn -> Mix.Tasks.ExGram.Router.Flat.run([]) end)
      end
    end
  end

  describe "run/1 with a non-existent module" do
    test "raises Mix.Error" do
      assert_raise Mix.Error, fn ->
        capture_io(fn ->
          Mix.Tasks.ExGram.Router.Flat.run(["DoesNotExist.Whatsoever"])
        end)
      end
    end
  end

  describe "run/1 with a module that is not a router" do
    test "raises Mix.Error" do
      assert_raise Mix.Error, fn ->
        capture_io(fn ->
          Mix.Tasks.ExGram.Router.Flat.run(["String"])
        end)
      end
    end
  end
end
