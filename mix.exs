defmodule ExGramRouter.MixProject do
  use Mix.Project

  @source_url "https://github.com/rockneurotiko/ex_gram_router"
  @version "0.1.0"

  def project do
    [
      app: :ex_gram_router,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      source_url: @source_url,
      docs: docs(),
      dialyzer: dialyzer(),
      aliases: aliases()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp description do
    "Declarative routing DSL for ExGram Telegram bots"
  end

  defp package do
    [
      maintainers: ["Miguel Garcia / Rock Neurotiko"],
      licenses: ["Beerware"],
      links: %{"GitHub" => @source_url},
      files: ~w(.formatter.exs lib mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v" <> @version,
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        DSL: [ExGram.Router],
        Filters: ~r/ExGram\.Router\.Filter.*/,
        Core: ~r/ExGram\.Router\.(Compiler|Dispatcher|Scope|Dsl)/
      ]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix]
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test",
        "credo",
        "dialyzer"
      ]
    ]
  end

  defp deps do
    [
      {:ex_gram, "~> 0.64"},
      # Development
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:quokka, "~> 2.12", only: [:dev, :test], runtime: false}
    ]
  end
end
