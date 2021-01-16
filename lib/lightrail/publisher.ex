defmodule Lightrail.Publisher do
  @moduledoc """
  A behaviour module for implementing a publisher.

  * allows publisher configuration to be set

  * starts a `Lightrail.Publisher.Server` process that tracks connection
    information state

  * provides a `publish` function that takes a Protobuf, encodes it, and
    publishes it to the configured exchange

  ## Example

  ```
  defmodule ExamplePublisher do
    @behaviour Lightrail.Publisher

    def start_link() do
      Lightrail.Publisher.start_link(__MODULE__, name: __MODULE__)
    end

    def publish_test_message() do
      proto = Test.Message.new(uuid: UUID.uuid4())
      Lightrail.Publisher.publish(__MODULE__, proto)
    end

    @impl Lightrail.Publisher
    def init() do
      [
        exchange: "lightrail_example_exchange",
        connection: "amqp://guest:guest@localhost:5672"
      ]
    end
  end
  ```

  """

  alias Lightrail.MessageFormat.BinaryProtobuf

  @doc """
  Used to provide publisher configuration.

  ## Required Values

  `connection` - Message bus connection information. If using RabbitMQ as a
                 message bus, this is the connection URI
                 (i.e. `amqp://guest:guest@localhost:5672`).

  `exchange` - The name of the exchange used to publish messages.

  ## Examples

  ```
  @impl Lightrail.Publisher
  def init() do
    [
      exchange: "example",
      connection: "amqp://guest:guest@localhost:5672"
    ]
  end
  ```

  """
  @callback init() :: [connection: String.t(), exchange: String.t()]

  @doc """
  Starts the `Lightrail.Publisher` process with the given callback module
  linked to the current process.

  `module` - Callback module implementing `Lightrail.Publisher` behaviour.

  ## Options
   * `:name` - used for name registration

  ## Return values
  If the publisher is successfully created and initialized, this function
  returns `{:ok, pid}`, where `pid` is the PID of the publisher. If a
  process with the specified publisher name already exists, this function
  returns `{:error, {:already_started, pid}}` with the PID of that process.

  ## Examples:

  ```
  Lightrail.Publisher.start_link(__MODULE__, name: __MODULE__)
  ```

  """
  @spec start_link(module, Keyword.t()) :: {:ok, pid} | {:error, term}
  def start_link(module, options \\ []) do
    GenServer.start_link(Lightrail.Publisher.Server, %{module: module}, options)
  end

  @doc """
  Encode and publish the given `protobuf` to the configured exchange.

  `pid` - Name or PID of the publisher.

  `protobuf` - The Protobuf to publish.

  ## Examples

  ```
  proto = Test.Message.new(uuid: UUID.uuid4())
  Lightrail.Publisher.publish(__MODULE__, proto)
  ```

  """
  @spec publish(pid, struct) :: :ok | {:error, term}
  def publish(pid, protobuf) do
    case BinaryProtobuf.encode(protobuf) do
      {:ok, message} ->
        GenServer.call(pid, {:publish, message})

      {:error, error} ->
        {:error, "An error occurred while attempting to publish a message. #{error}"}
    end
  end
end
