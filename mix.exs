defmodule Superls.MixProject do
  use Mix.Project

  @version "0.2.0"
  def project do
    [
      app: :superls,
      version: @version,
      elixir: "~> 1.15-dev",
      package: package(),
      description: "A files indexer and search engine elixir CLI.",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: Superls.CLI],
      deps: deps(),
      docs: [
        main: "Superls",
        source_ref: "v#{@version}",
        source_url: "https://github.com/bougueil/superls"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:flow, "~> 1.2.4"},
      {:benchee, "~> 1.1", only: :test, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: :docs}
    ]
  end

  defp package do
    %{
      licenses: ["Apache-2.0"],
      maintainers: ["Renaud Mariana"],
      links: %{"GitHub" => "https://github.com/bougueil/superls"}
    }
  end
end
