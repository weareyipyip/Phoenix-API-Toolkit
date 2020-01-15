defmodule PhoenixApiToolkit.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_api_toolkit,
      version: "0.10.0",
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
      ],
      source_url: "https://github.com/weareyipyip/Phoenix-API-Toolkit",
      name: "Phoenix API Toolkit",
      docs: [
        source_ref: "master",
        extras: ["./README.md"],
        main: "readme"
      ],
      dialyzer: [
        plt_add_apps: [:jose]
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
      # meta / dev dependencies
      {:ex_doc, "~> 0.21", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :test], runtime: false},

      # application dependencies
      {:ecto, "~> 3.0"},
      {:plug, "~> 1.8"},
      {:jason, "~> 1.0"},
      {:jose, "~> 1.9", optional: true},
      {:pow, ">= 1.0.15", optional: true}
    ]
  end
end
