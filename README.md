# Lightrail

The purpose of the project is two-fold. The main reason is for me (Bob) to learn Elixir on a non-trivial codebase. The secondary reason is to provide a playground for architecture experiments that may or may not wind up in the [RailwayIPC](https://github.com/learn-co/railway_ipc) hex package.

## Installation / Development

This project is _not_ intended to be published to Hex. Install by cloning this repo and running the `bin/setup` script. A `bin/precommit` helper script is available that will compile, test and lint code.

## Architecture Overview
![Architecture](xref_graph.png)

## Notes

### iex Helpers
Several aliases are provided to make dealing with the repo easier. See the `.iex.exs` file in the project root for details.

### Installation for Clients (example docs)
1. Add `lightrail` to your list of dependencies in `mix.exs`:

```
def deps do
  [{:lightrail, "~> 0.1"}]
end
```

2. Ensure `lightrail` is started before your application:

```
def application do
  [applications: [:lightrail]]
end
```

3. Configure Lightrail. Lightrail does not ship with its own repo. Use your application's repo. You must also specify a message bus adapter and connection URI.

```
config :lightrail,
  message_bus: Lightrail.RabbitMQ.Adapter,
  message_bus_uri: "amqp://guest:guest@localhost:5672",
  repo: MyApp.Repo
```

4. Create a migration for the message tables by running:

```
mix lightrail.gen.migration
```

5. Migrate

```
mix ecto.migrate
```

### Testing Publisher/Consumer GenServers

Originally I had a few tests that exercised the publisher and consumer GenServers directly. After dealing with them for awhile I opted against using them and instead test GenServers through their respective interfaces (i.e. `publisher_test.exs` and `consumer_test.exs`). There a few reasons for this.

* The GenServers contain very little logic. They're job is to contain state and delegate work out to functions in other modules. Those other modules already have tests (and don't have to deal with state).

* I don't think it worth writing tests to make sure they're state is tracked correctly since it would require calling into GenServer internals. We can instead infer that the state is correct through higher level tests.

* The only tests worth writing directly for the GenServers are around publishing a message and consuming one -- these tests can be done at a higher level instead.

* I researched some open source projects and blogs posts to see how others deal with these types of tests. Opinions vary, but I found quite a few that advocate for this approach. It is also the approach they recommend in the "Testing a GenServer" chapter of the book "Testing Elixir".

### Unit Tests vs. Integration Tests
All integration tests are tagged (`@tag :integration`) so that they can be run separately. They are slower than the regular untagged unit tests since they need to assert that messages have been published, queues are empty, etc. By default, running `mix test` will exclude these slow RabbitMQ tests. They can be ran using the `mix test --only integration` command or by using the `/bin/precommit` script. The `bin/precommit` script will run them as a last step after the other tests, credo, etc. CI will always run the integration tests as well.

### Logs Output During Test Runs
Originally I had set the log level for the test environment to `:critical` to prevent logs from polluting the test output. This was a mistake. Several errors were occurring that were being hidden, so I set the log level to `:warning`.

There are currently two tests in the `Lightrail.MessageBus.RabbitmqTest` module in the "setting up a consumer" block that are emitting error log messages. AFAICT these errors aren't harming anything, they're do to the way the tests are setup. I couldn't figure out a way to silence them; will revisit at a later date. For reference, the messages look like this:

```
[error] gen_server <0.532.0> terminated with reason: unexpected_delivery_and_no_default_consumer
[error] CRASH REPORT Process <0.532.0> with 0 neighbours exited with reason: unexpected_delivery_and_no_default_consumer in gen_server2:terminate/3 line 1183
[error] Supervisor {<0.531.0>,amqp_channel_sup} had child gen_consumer started with amqp_gen_consumer:start_link(amqp_selective_consumer, [], {<<"client 127.0.0.1:55497 -> 127.0.0.1:5672">>,1}) at <0.532.0> exit with reason unexpected_delivery_and_no_default_consumer in context child_terminated
[error] Supervisor {<0.531.0>,amqp_channel_sup} had child gen_consumer started with amqp_gen_consumer:start_link(amqp_selective_consumer, [], {<<"client 127.0.0.1:55497 -> 127.0.0.1:5672">>,1}) at <0.532.0> exit with reason reached_max_restart_intensity in context shutdown
```

## TODO
This is a non-exhaustive list of things in no particular order that I'd like to implement, think about, or try:

- [ ] row locking for consumed messages to prevent concurrent processing
- [ ] remove specs from non-public API modules
- [ ] mix task for generating migrations
- [x] setup telemetry for publisher genserver
- [x] setup telemetry for consumer genserver
- [x] setup telemetry for MessageBus.RabbitMQ
- [x] replace all hard-coded rabbitmq connection strings in tests
- [x] fix TODOs in Publisher
- [x] how should protobuf encoding work?
- [x] fix TODOs in Consumer
- [x] how should protobuf decoding work?
- [x] create a pre-commit script (clean, compile, test, credo, check format)
- [x] setup credo config file
- [x] fix TODOs in Publisher.Server
- [x] fix TODOs in Consumer.Server
- [x] fix TODOs in MessageBus.RabbitMQ
- [x] message bus behaviour? -- don't think it's needed, overkill
- [x] generate UUID's for message if they're not provided
- [x] message persistence for published messages
- [x] setup script should create DB and run migrations (both envs)
- [x] message persistence for consumed messages
- [x] figure out how auto-generated docs work (also saw references in some places about executable docs)
- [x] look into using `ex_rabbit_pool` for connections
- [x] how should supervisors work? develop consumer strategy
- [~] command messages (both publishing & consuming); how should they work? when should they be used?
- [~] RPC support
