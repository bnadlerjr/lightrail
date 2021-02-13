defmodule Lightrail.MessageStore do
  @moduledoc """
  Behaviour specification for message persistence.

  """

  defmodule OutgoingMessage do
    @moduledoc """
    Represents an outgoing message and it metadata.

    """
    defstruct [:protobuf, :encoded, :exchange, :type]
  end

  defmodule IncomingMessage do
    @moduledoc """
    Represents an incoming message and it metadata.

    """
    defstruct [:protobuf, :encoded, :exchange, :type, :queue]
  end

  @doc """
  Inserts an outgoing message into the message store.

  """
  @callback insert(message :: %__MODULE__.OutgoingMessage{}) ::
              {:ok, term} | {:error, term}

  @doc """
  Upserts an incoming message into the message store.

  """
  @callback upsert(message :: %__MODULE__.IncomingMessage{}) :: {:ok, term} | {:error, term}

  @doc """
  Transitions status of an incoming message.

  """
  @callback transition_status(message :: %__MODULE__.IncomingMessage{}, status :: binary) ::
              {:ok, term} | {:error, term}
end
