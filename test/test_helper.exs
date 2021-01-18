# RabbitMQ integration tests are slow and require a running RabbitMQ
# instance so don't run them by default. You can run them using
# `mix test --only rabbit`. CI will always run them.
ExUnit.configure(exclude: [rabbit: true])

ExUnit.start(capture_log: true)
