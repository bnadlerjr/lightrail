defmodule Lightrail.Consumer do
  @moduledoc """
  A behaviour module for implementing a consumer.

  * allows consumer configuration to be set

  * starts a `Lightrail.Consumer.Server` process that tracks connection
    information state

  * provides a `handle_message` callback that receives a decoded
    protobuf struct

  ## Example

  ```
  defmodule ExampleConsumer do
    @behaviour Lightrail.Consumer

    def start_link() do
      Lightrail.Consumer.start_link(__MODULE__, name: __MODULE__)
    end

    @impl Lightrail.Consumer
    def init() do
      [
        exchange: "lightrail_example_exchange",
        queue: "lightrail_example_queue",
        connection: "amqp://guest:guest@localhost:5672"
      ]
    end

    @impl Lightrail.Consumer
    def handle_message(_message) do
      # do something with the message
      :ok
    end
  end
  ```
  """

  require Logger

  @doc """
  Used to provide consumer configuration.

  ## Required Values

  `connection` - Message bus connection information. If using RabbitMQ as a
                 message bus, this is the connection URI
                 (i.e. `amqp://guest:guest@localhost:5672`).

  `exchange` - The name of the exchange to consume.

  `queue` - The name of the queue to consume.

  ## Examples

  ```
  @impl Lightrail.Consumer
  def init() do
    [
      exchange: "example",
      queue: "my_queue",
      connection: "amqp://guest:guest@localhost:5672"
    ]
  end
  ```

  """
  @callback init() :: [connection: String.t(), exchange: String.t(), queue: String.t()]

  @doc """
  Message handler. This callback will be called when a message is consumed. If
  an error occurs when handling the message, this function should return
  `:error`, which will cause the message bus to reject the message. Any other
  return value will be considered successful, and the message bus will
  acknowledge the message.

  ## Example

  ```
  @impl Lightrail.Consumer
  def handle_message(message) do
    # do something with the message
    :ok
  end
  ```

  """
  @callback handle_message(message :: keyword) :: :ok | :error

  @doc """
  Starts the `Lightrail.Consumer` process with the given callback module
  linked to the current process.

  `module` - Callback module implementing `Lightrail.Consumer` behaviour.

  ## Options
   * `:name` - used for name registration

  ## Return values
  If the consumer is successfully created and initialized, this function
  returns `{:ok, pid}`, where `pid` is the PID of the consumer. If a
  process with the specified consumer name already exists, this function
  returns `{:error, {:already_started, pid}}` with the PID of that process.

  ## Examples:

  ```
  Lightrail.Consumer.start_link(__MODULE__, name: __MODULE__)
  ```

  """
  @spec start_link(module, Keyword.t()) :: {:ok, pid} | {:error, term}
  def start_link(module, options \\ []) do
    GenServer.start_link(Lightrail.Consumer.Server, %{module: module}, options)
  end

  @doc """
  Stops the consumer.

  """
  @spec stop(pid, term) :: :ok
  def stop(pid, reason \\ :normal) do
    GenServer.stop(pid, reason)
  end
end
