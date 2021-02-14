defmodule Lightrail.MessageStore.DB.Adapter do
  @moduledoc """
  Deals with peristing messages to the database.

  This is an internal module, not part of the public API.

  """

  import Ecto.Query

  alias Lightrail.MessageStore.DB.ConsumedMessage
  alias Lightrail.MessageStore.DB.Errors
  alias Lightrail.MessageStore.DB.PublishedMessage
  alias Lightrail.MessageStore.IncomingMessage
  alias Lightrail.MessageStore.OutgoingMessage

  @behaviour Lightrail.MessageStore
  @repo Application.compile_env(:lightrail, :repo)

  def insert(%OutgoingMessage{} = msg) do
    params = message_to_params(msg, "sent")

    with {:error, changeset} <- do_insert(params) do
      {:error, Errors.format(changeset)}
    end
  end

  def upsert(%IncomingMessage{} = msg) do
    params = message_to_params(msg, "processing")

    with {:error, changeset} <- do_upsert(params) do
      {:error, Errors.format(changeset)}
    end
  end

  def transition_status(%IncomingMessage{} = msg, status) do
    %{protobuf: proto, exchange: exchange} = msg

    case find_consumed_message(proto.uuid, exchange) do
      nil ->
        {:error,
         "Unable to find consumed message " <>
           "(#{inspect(proto.uuid)}, #{inspect(exchange)})"}

      message ->
        with {:error, changeset} <- do_transition(message, status) do
          {:error, Errors.format(changeset)}
        end
    end
  end

  defp do_insert(params) do
    %PublishedMessage{}
    |> PublishedMessage.changeset(params)
    |> @repo.insert()
  end

  defp do_upsert(params) do
    case find_consumed_message(params.uuid, params.exchange) do
      nil ->
        %ConsumedMessage{}
        |> ConsumedMessage.changeset(params)
        |> @repo.insert()

      %{status: status} = msg when status == "processing" ->
        {:skip, msg}

      msg ->
        msg
        |> ConsumedMessage.changeset(params)
        |> @repo.update()
    end
  end

  defp do_transition(message, status) do
    message
    |> ConsumedMessage.transition(status)
    |> @repo.update()
  end

  defp find_consumed_message(uuid, exchange) do
    from(m in ConsumedMessage, where: m.uuid == ^uuid, where: m.exchange == ^exchange)
    |> @repo.one
  end

  defp message_to_params(%{queue: queue} = msg, status) do
    params = message_to_params(Map.drop(msg, [:queue]), status)
    Map.merge(params, %{queue: queue})
  end

  defp message_to_params(msg, status) do
    %{protobuf: protobuf, encoded: encoded, exchange: exchange, type: type} = msg

    %{
      correlation_id: protobuf.correlation_id,
      encoded_message: encoded,
      exchange: exchange,
      message_type: type,
      status: status,
      user_uuid: protobuf.user_uuid,
      uuid: protobuf.uuid
    }
  end
end
