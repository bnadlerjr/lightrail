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

  require Logger

  alias Lightrail.Message
  alias Lightrail.Messages

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
   * `:name` - Used for name registration.
   * `:bus` - Module to use for the message bus. Defaults to
              `Lightrail.MessageBus.RabbitMQ` if not given.

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
    server_options = Keyword.drop(options, [:bus])

    initial_state = %{
      module: module,
      bus: Keyword.get(options, :bus, Lightrail.MessageBus.RabbitMQ)
    }

    GenServer.start_link(Lightrail.Publisher.Server, initial_state, server_options)
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
  @spec publish(module, struct) :: :ok | {:error, term}
  def publish(pid, protobuf) do
    %{protobuf: protobuf, pid: pid}
    |> prepare_msg()
    |> call_genserver()
    |> persist()
    |> log_details()
  end

  defp prepare_msg(%{protobuf: protobuf} = state) do
    case Message.prepare_for_publishing(protobuf) do
      {:ok, message, type} ->
        {:ok, Map.merge(state, %{message: message, type: type})}

      {:error, error} ->
        {:error, error}
    end
  end

  defp call_genserver({:ok, %{pid: pid, message: message} = state}) do
    case GenServer.call(pid, {:publish, message}) do
      {:ok, exchange} ->
        {:ok, Map.merge(state, %{exchange: exchange})}

      {:error, error} ->
        {:error, error}
    end
  end

  defp call_genserver({:error, error}), do: {:error, error}

  defp persist({:ok, %{protobuf: proto, message: msg, exchange: exch, type: type} = state}) do
    case Messages.insert(%{protobuf: proto, encoded: msg, exchange: exch, type: type}) do
      {:ok, _} -> {:ok, state}
      {:error, error} -> {:error, error}
    end
  end

  defp persist({:error, error}), do: {:error, error}

  defp log_details({:ok, %{type: type, exchange: exchange} = state}) do
    Logger.info("[#{__MODULE__}]: Published a #{inspect(type)} message to #{inspect(exchange)}")
    {:ok, state}
  end

  defp log_details({:error, error}) do
    msg = "Failed to publish message. #{inspect(error)}"
    Logger.error("[#{__MODULE__}]: #{msg}")
    {:error, msg}
  end
end
