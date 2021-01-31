defmodule Lightrail.Messages do
  @moduledoc """
  Deals with peristing messages to the database.

  This is an internal module, not part of the public API.

  """

  import Ecto.Query

  alias Lightrail.Messages.ConsumedMessage
  alias Lightrail.Messages.Errors
  alias Lightrail.Messages.PublishedMessage

  @repo Application.compile_env(:lightrail, :repo)

  def insert(%{protobuf: protobuf, encoded: encoded, exchange: exchange, type: type}) do
    params = %{
      correlation_id: protobuf.correlation_id,
      encoded_message: encoded,
      exchange: exchange,
      message_type: type,
      status: "sent",
      user_uuid: protobuf.user_uuid,
      uuid: protobuf.uuid
    }

    with {:error, changeset} <- do_insert(params) do
      {:error, Errors.format(changeset)}
    end
  end

  def upsert(%{protobuf: proto, encoded: encoded, exchange: exchange, type: type, queue: queue}) do
    params = %{
      correlation_id: proto.correlation_id,
      encoded_message: encoded,
      exchange: exchange,
      message_type: type,
      queue: queue,
      status: "processing",
      user_uuid: proto.user_uuid,
      uuid: proto.uuid
    }

    with {:error, changeset} <- do_upsert(params) do
      {:error, Errors.format(changeset)}
    end
  end

  def transition_status(message, status) do
    with {:error, changeset} <- do_transition(message, status) do
      {:error, Errors.format(changeset)}
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
end
