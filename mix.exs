defmodule Lightrail.MixProject do
  use Mix.Project

  def project do
    [
      app: :lightrail,
      version: "0.1.0",
      elixir: "~> 1.10",
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
      {:telemetry, "~> 0.4"}
    ]
  end
end
