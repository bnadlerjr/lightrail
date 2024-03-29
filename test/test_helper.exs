# Integration tests are slow and require a running RabbitMQ
# instance so don't run them by default. You can run them using
# `mix test --only integration`. CI will always run them.
ExUnit.configure(exclude: [integration: true])

Test.Support.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Test.Support.Repo, :manual)

ExUnit.start(capture_log: true)
