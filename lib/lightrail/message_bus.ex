defmodule Lightrail.MessageBus do
  @moduledoc """
  Defines message bus behaviour.

  """

  defstruct [:channel, :exchange, :queue]

  @doc """
  Takes configuration struct and sets up any needed infrastructure for the
  message bus to publish a message. Returns the updated configuration struct.

  """
  @callback setup_publisher(state :: %__MODULE__{}) :: {:ok, %__MODULE__{}}

  @doc """
  Takes configuration struct and sets up any needed infrastructure for the
  message bus to consume a message. Returns the updated configuration struct.

  """
  @callback setup_consumer(state :: %__MODULE__{}) :: {:ok, %__MODULE__{}}

  @doc """
  Instructs the message bus to acknowledge a message.

  """
  @callback ack(state :: %__MODULE__{}, metadata :: map) :: :ok | {:error, term}

  @doc """
  Instructs the message bus to reject a message.

  """
  @callback reject(state :: %__MODULE__{}, metadata :: map) :: :ok | {:error, term}

  @doc """
  Publish a message on the message bus.

  """
  @callback publish(state :: %__MODULE__{}, message :: String.t()) :: :ok | {:error, term}

  @doc """
  Cleanup any infrastructure that the message bus has created (connections,
  channels, etc.).

  """
  @callback cleanup(state :: %__MODULE__{}) :: {:ok, %__MODULE__{}}

  @doc """
  Open a new message bus connection.

  """
  @callback connect(uri :: binary) :: {:ok, term}

  @doc """
  Close the message bus connection.

  """
  @callback disconnect(connection :: term) :: :ok
end
