defmodule Test.Support.DataCase do
  @moduledoc """
  Test helpers for dealing with the database and Ecto.

  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Lightrail.MessageStore.DB.ConsumedMessage
  alias Lightrail.MessageStore.DB.PublishedMessage
  alias Test.Support.Repo

  using do
    quote do
      import Test.Support.DataCase
    end
  end

  setup context do
    :ok = Sandbox.checkout(Repo)

    unless context[:async] do
      Sandbox.mode(Repo, {:shared, self()})
    end

    context
  end

  def row_count(table, field \\ :uuid) do
    Repo.aggregate(table, :count, field)
  end

  def get_consumed_message!(uuid, queue \\ "lightrail:test:event") do
    Repo.get_by!(ConsumedMessage, %{uuid: uuid, queue: queue})
  end

  def get_published_message!(uuid) do
    Repo.get!(PublishedMessage, uuid)
  end

  def insert_consumed_message!(proto, encoded, type, exchange, queue, status) do
    params = %{
      correlation_id: proto.correlation_id,
      encoded_message: encoded,
      exchange: exchange,
      message_type: type,
      queue: queue,
      status: status,
      user_uuid: proto.user_uuid,
      uuid: proto.uuid
    }

    %ConsumedMessage{}
    |> ConsumedMessage.changeset(params)
    |> Repo.insert!()
  end

  def insert_consumed_message!(%ConsumedMessage{} = msg) do
    Repo.insert!(msg)
  end
end
