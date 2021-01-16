defmodule Lightrail.MixProject do
  use Mix.Project

  def project do
    [
      app: :lightrail,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:amqp, "~> 1.2"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:google_protos, "~> 0.1"},
      {:jason, "~> 1.1"},
      {:protobuf, "~> 0.5.3"},
      {:telemetry, "~> 0.4"},
      {:uuid, "~> 1.1"}
    ]
  end

  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
