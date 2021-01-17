defmodule Lightrail.Message do
  @moduledoc """
  Business logic that prepares messages for publishing and consuming. Handles
  encoding, decoding, etc.

  """

  require Logger

  alias Lightrail.MessageFormat.BinaryProtobuf

  @doc """
  Takes a `protobuf` and prepares it for publishing by encoding it in
  a message format.

  """
  @spec prepare_for_publishing(struct) :: {:ok, String.t()} | {:error, String.t()}
  def prepare_for_publishing(protobuf) do
    BinaryProtobuf.encode(protobuf)
  end

  @doc """
  Takes a JSON `payload`, decodes it, and consumes it by applying a
  handler function.

  """
  @spec consume(String.t(), module) :: :ok | :error
  def consume(payload, module) do
    case BinaryProtobuf.decode(payload) do
      {:ok, proto} ->
        apply(module, :handle_message, [proto])

      {:error, error} ->
        Logger.error("[#{module}]: An error occurred while decoding a message. #{error}")
        :error
    end
  end
end
