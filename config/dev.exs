use Mix.Config

config :logger, level: :info

config :lightrail, Test.Support.Repo,
  database: "lightrail_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true

config :lightrail,
  ecto_repos: [Test.Support.Repo],
  message_bus: Lightrail.RabbitMQ.Adapter,
  message_bus_uri: "amqp://guest:guest@localhost:5672",
  repo: Test.Support.Repo
