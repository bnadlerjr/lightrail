defmodule ExampleConsumer do
  @moduledoc """
  Example Consumer implementation.

  Sample usage:

  ```
  iex -S mix
  iex(1)> ExampleConsumer.start_link()
  ```

  """

  @behaviour Lightrail.Consumer

  def start_link() do
    Lightrail.Consumer.start_link(__MODULE__, name: __MODULE__)
  end

  @impl Lightrail.Consumer
  def init() do
    [
      queue: "lightrail_example_queue",
      exchange: "lightrail_example_exchange",
      connection: "amqp://guest:guest@localhost:5672"
    ]
  end

  @impl Lightrail.Consumer
  def handle_message(message) do
    # Process the message however you want (i.e. make HTTP request,
    # update DB, etc.)
    IO.puts("Handled message: #{inspect(message)}")
  end

  @impl Lightrail.Consumer
  def handle_error(message, reason) do
    # Perform any error handling you want (i.e. write a special log, make
    # an HTTP call, etc.).
    IO.puts("Message error: #{reason} (#{inspect(message)})")
  end
end
