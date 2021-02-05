use Mix.Config

config :logger, level: :warning

config :lightrail, Test.Support.Repo,
  database: "lightrail_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox

config :lightrail,
  ecto_repos: [Test.Support.Repo],
  message_bus: Test.Support.FakeRabbitMQ,
  message_bus_uri: "amqp://guest:guest@localhost:5672",
  repo: Test.Support.Repo
