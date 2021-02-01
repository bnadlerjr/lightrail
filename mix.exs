defmodule Lightrail.MixProject do
  use Mix.Project

  def project do
    [
      app: :lightrail,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      source_url: "https://github.com/flatiron-labs/lightrail",
      homepage_url: "https://github.com/flatiron-labs/lightrail",
      dialyzer: [flags: ["-Wunmatched_returns", :error_handling, :underspecs]],
      docs: [
        main: "README",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:lager, :logger]
    ]
  end

  defp deps do
    [
      {:amqp, "~> 1.2"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},

      # Not great, but the master branch supports configurable state fields
      # and the latest release does not
      {:fsmx, git: "https://github.com/subvisual/fsmx.git", branch: "master"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:google_protos, "~> 0.1"},
      {:jason, "~> 1.1"},
      {:postgrex, ">= 0.0.0"},
      {:protobuf, "~> 0.5.3"},
      {:telemetry, "~> 0.4"},
      {:uuid, "~> 1.1"}
    ]
  end

  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
