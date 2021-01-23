defmodule Lightrail.Messages.ConsumedMessage do
  @moduledoc """
  Schema and helpers for a consumed message.

  This is an internal module, not part of the public API.

  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "lightrail_consumed_messages" do
    field(:correlation_id, :binary_id)
    field(:encoded_message, :string)
    field(:exchange, :string)
    field(:message_type, :string)
    field(:queue, :string, primary_key: true)
    field(:status, :string)
    field(:user_uuid, :binary_id)
    field(:uuid, :binary_id, primary_key: true)

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, permitted_fields())
    |> validate_required([:encoded_message, :message_type, :queue, :status, :uuid])
  end

  defp permitted_fields do
    [
      :correlation_id,
      :encoded_message,
      :exchange,
      :message_type,
      :queue,
      :status,
      :user_uuid,
      :uuid
    ]
  end
end
