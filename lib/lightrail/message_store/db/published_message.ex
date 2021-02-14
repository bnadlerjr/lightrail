defmodule Lightrail.MessageStore.DB.PublishedMessage do
  @moduledoc """
  Schema and helpers for a published message.

  This is an internal module, not part of the public API.

  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:uuid, :binary_id, autogenerate: false}

  schema "lightrail_published_messages" do
    field(:correlation_id, :binary_id)
    field(:encoded_message, :string)
    field(:exchange, :string)
    field(:message_type, :string)
    field(:status, :string)
    field(:user_uuid, :binary_id)
    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, permitted_fields())
    |> validate_required([:encoded_message, :message_type, :status, :uuid])
    |> unique_constraint(:uuid, name: "lightrail_published_messages_pkey")
  end

  defp permitted_fields do
    [
      :correlation_id,
      :encoded_message,
      :exchange,
      :message_type,
      :status,
      :user_uuid,
      :uuid
    ]
  end
end
