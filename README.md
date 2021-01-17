# Lightrail

The purpose of the project is two-fold. The main reason is for me (Bob) to learn Elixir on a non-trivial codebase. The secondary reason is to provide a playground for architecture experiments that may or may not wind up in the [RailwayIPC](https://github.com/learn-co/railway_ipc) hex package.

## Installation / Development

This project is _not_ intended to be published to Hex. Install by cloning this repo and running the `bin/setup` script. A `precommit` helper script is available that will compile, test and lint code.

## TODO
This is a non-exhaustive list of things in no particular order that I'd like to implement, think about, or try:

[ ] fix TODOs in Consumer.Server
[ ] fix TODOs in MessageBus.RabbitMQ
[ ] how should supervisors work? develop consumer strategy
[ ] message persistence for published messages
[ ] message persistence for consumed messages
[ ] figure out how auto-generated docs work
[ ] generate UUID's for message if they're not provided
[ ] commands (both publishing & consuming); how should they work? when should they be used?
[ ] RPC support
[ ] message bus behaviour?
[ ] setup telemetry for publisher genserver
[x] fix TODOs in Publisher
[x] how should protobuf encoding work?
[x] fix TODOs in Consumer
[x] how should protobuf decoding work?
[x] create a pre-commit script (clean, compile, test, credo, check format)
[x] setup credo config file
[x] fix TODOs in Publisher.Server
