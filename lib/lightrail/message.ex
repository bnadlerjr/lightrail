defmodule Lightrail.Message do
  @moduledoc """
  Business logic that prepares messages for publishing and consuming. Handles
  encoding, decoding, etc.

  """

  alias Lightrail.MessageFormat.BinaryProtobuf

  @doc """
  Takes a `protobuf` and prepares it for publishing by encoding it in
  a message format.

  """
  def prepare_for_publishing(protobuf) do
    protobuf
    |> ensure_message_uuid()
    |> ensure_correlation_id()
    |> BinaryProtobuf.encode()
  end

  @doc """
  Takes a JSON `payload` and decodes it.

  """
  def decode(payload) do
    BinaryProtobuf.decode(payload)
  end

  defp ensure_message_uuid(%{uuid: uuid} = proto) when is_nil(uuid) or "" == uuid do
    Map.put(proto, :uuid, UUID.uuid4())
  end

  defp ensure_message_uuid(proto), do: proto

  defp ensure_correlation_id(%{correlation_id: id} = proto) when is_nil(id) or "" == id do
    Map.put(proto, :correlation_id, UUID.uuid4())
  end

  defp ensure_correlation_id(proto), do: proto
end
