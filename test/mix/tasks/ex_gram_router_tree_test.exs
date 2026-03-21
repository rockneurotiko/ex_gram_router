defmodule Mix.Tasks.ExGram.Router.TreeTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  # ---------------------------------------------------------------------------
  # Support: a minimal router bot for inspection
  # ---------------------------------------------------------------------------

  defmodule TreeTestHandlers do
    def start(context), do: context
    def help(context), do: context
    def fallback(context), do: context
    def echo(update_info, context), do: {update_info, context}
  end

  defmodule TreeTestFilter do
    @behaviour ExGram.Router.Filter

    @impl ExGram.Router.Filter
    def call(_update_info, _context, _opts), do: true
  end

  defmodule TreeTestBot do
    use ExGram.Bot, name: :tree_test_bot
    use ExGram.Router

    alias_filter(Mix.Tasks.ExGram.Router.TreeTest.TreeTestFilter, as: :tree_test_filter)

    scope do
      filter(:command, :start)
      handle(&Mix.Tasks.ExGram.Router.TreeTest.TreeTestHandlers.start/1)
    end

    scope do
      filter(:command, :help)
      handle(&Mix.Tasks.ExGram.Router.TreeTest.TreeTestHandlers.help/1)
    end

    scope do
      filter(:tree_test_filter, :some_state)

      scope do
        filter(:command, :echo)
        handle(&Mix.Tasks.ExGram.Router.TreeTest.TreeTestHandlers.echo/2)
      end
    end

    scope do
      handle(&Mix.Tasks.ExGram.Router.TreeTest.TreeTestHandlers.fallback/1)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp run_task(module_name) do
    capture_io(fn ->
      Mix.Tasks.ExGram.Router.Tree.run([module_name])
    end)
  end

  # ---------------------------------------------------------------------------
  # Tests: successful rendering
  # ---------------------------------------------------------------------------

  describe "run/1 with a valid router module" do
    test "prints the module name as the header" do
      output = run_task("Mix.Tasks.ExGram.Router.TreeTest.TreeTestBot")
      assert output =~ "TreeTestBot routing tree"
    end

    test "prints scope entries for each top-level scope" do
      output = run_task("Mix.Tasks.ExGram.Router.TreeTest.TreeTestBot")
      assert output =~ "scope"
    end

    test "prints filter info with short module name and opts" do
      output = run_task("Mix.Tasks.ExGram.Router.TreeTest.TreeTestBot")
      assert output =~ "Command(:start)"
      assert output =~ "Command(:help)"
    end

    test "prints filter with no opts as just the short name" do
      output = run_task("Mix.Tasks.ExGram.Router.TreeTest.TreeTestBot")
      # The tree_test_filter has opts :some_state
      assert output =~ "TreeTestFilter(:some_state)"
    end

    test "prints handle lines with module, function, and arity" do
      output = run_task("Mix.Tasks.ExGram.Router.TreeTest.TreeTestBot")
      assert output =~ "TreeTestHandlers.start/1"
      assert output =~ "TreeTestHandlers.help/1"
      assert output =~ "TreeTestHandlers.echo/2"
      assert output =~ "TreeTestHandlers.fallback/1"
    end

    test "uses box-drawing characters for tree structure" do
      output = run_task("Mix.Tasks.ExGram.Router.TreeTest.TreeTestBot")
      assert output =~ "└── "
      assert output =~ "├── "
    end

    test "branch scopes show nested child scopes" do
      output = run_task("Mix.Tasks.ExGram.Router.TreeTest.TreeTestBot")
      # The branch with TreeTestFilter has a child with Command(:echo)
      assert output =~ "Command(:echo)"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: error cases
  # ---------------------------------------------------------------------------

  describe "run/1 with no arguments" do
    test "raises Mix.Error with a usage message" do
      assert_raise Mix.Error, fn ->
        capture_io(fn -> Mix.Tasks.ExGram.Router.Tree.run([]) end)
      end
    end
  end

  describe "run/1 with a non-existent module" do
    test "raises Mix.Error" do
      assert_raise Mix.Error, fn ->
        capture_io(fn ->
          Mix.Tasks.ExGram.Router.Tree.run(["DoesNotExist.Whatsoever"])
        end)
      end
    end
  end

  describe "run/1 with a module that is not a router" do
    test "raises Mix.Error" do
      assert_raise Mix.Error, fn ->
        capture_io(fn ->
          Mix.Tasks.ExGram.Router.Tree.run(["String"])
        end)
      end
    end
  end
end
