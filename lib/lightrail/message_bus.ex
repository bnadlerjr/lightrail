defmodule Lightrail.MessageBus do
  @moduledoc """
  Defines message bus behaviour.

  All functions defined by this behaviour take a configuration map as
  their first argument.
  """

  @doc """
  Takes configuration map and sets up any needed infrastructure for the
  message bus to publish a message. Returns the updated configuration map.

  """
  @callback setup_publisher(state :: map) :: {:ok, map}

  @doc """
  Takes configuration map and sets up any needed infrastructure for the
  message bus to consume a message. Returns the updated configuration map.

  """
  @callback setup_consumer(state :: map) :: {:ok, map}

  @doc """
  Instructs the message bus to acknowledge a message.

  """
  @callback ack(state :: map, metadata :: map) :: :ok | {:error, term}

  @doc """
  Instructs the message bus to reject a message.

  """
  @callback reject(state :: map, metadata :: map) :: :ok | {:error, term}

  @doc """
  Publish a message on the message bus.

  """
  @callback publish(state :: map, message :: String.t()) :: :ok | {:error, term}

  @doc """
  Cleanup any infrastructure that the message bus has created (connections,
  channels, etc.).

  """
  @callback cleanup(state :: map) :: {:ok, map}

  @doc """
  Open a new message bus connection.

  """
  @callback connect(uri :: binary) :: {:ok, term}

  @doc """
  Close the message bus connection.

  """
  @callback disconnect(connection :: map) :: :ok
end
