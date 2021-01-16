defmodule ExamplePublisher do
  @moduledoc """
  Example Publisher implementation.

  Sample usage:

  ```
  iex -S mix
  iex(1)> ExamplePublisher.start_link()
  iex(2)> ExamplePublisher.publish_message("test")
  ```

  """

  @behaviour Lightrail.Publisher

  def start_link() do
    Lightrail.Publisher.start_link(__MODULE__, name: __MODULE__)
  end

  def publish_message(message) do
    Lightrail.Publisher.publish(__MODULE__, message)
  end

  @impl Lightrail.Publisher
  def init() do
    [
      exchange: "lightrail_example_exchange",
      connection: "amqp://guest:guest@localhost:5672"
    ]
  end
end
