defmodule PhoenixApiToolkit.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_api_toolkit,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: """
      Library with helper modules for developing an API with Phoenix.
      """,
      package: [
        licenses: ["apache-2.0"],
        links: %{github: "https://github.com/weareyipyip/Phoenix-API-Toolkit"},
        source_url: "https://github.com/weareyipyip/Phoenix-API-Toolkit"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.21", only: [:dev, :test], runtime: false},
      {:ecto, "~> 3.0"}
    ]
  end
end
