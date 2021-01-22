defmodule Lightrail.Messages do
  @moduledoc """
  Deals with peristing messages to the database.

  This is an internal module, not part of the public API.

  """

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

  defp do_insert(params) do
    %PublishedMessage{}
    |> PublishedMessage.changeset(params)
    |> @repo.insert()
  end
end
