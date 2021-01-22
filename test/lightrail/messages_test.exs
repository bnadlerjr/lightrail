defmodule Lightrail.MessagesTest do
  use ExUnit.Case, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias Lightrail.MessageFormat.BinaryProtobuf
  alias Lightrail.Messages
  alias Lightrail.Messages
  alias Lightrail.Messages.PublishedMessage
  alias Test.Support.Message, as: Proto
  alias Test.Support.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
  end

  describe "#insert" do
    setup do
      proto = Proto.new(uuid: UUID.uuid4())
      {:ok, encoded, type} = BinaryProtobuf.encode(proto)

      args = %{
        protobuf: proto,
        type: type,
        exchange: "lightrail:test",
        encoded: encoded
      }

      %{valid_args: args}
    end

    test "valid message is persisted", %{valid_args: args} do
      {:ok, msg} = Messages.insert(args)
      persisted = Repo.get!(PublishedMessage, msg.uuid)
      assert args.encoded == persisted.encoded_message
      assert "lightrail:test" == persisted.exchange
      assert args.type == persisted.message_type
      assert "sent" == persisted.status
    end

    test "changeset errors are prettified", %{valid_args: args} do
      invalid_args = %{args | type: nil, encoded: nil}
      {:error, msg} = Messages.insert(invalid_args)
      assert "Encoded message can't be blank, Message type can't be blank" == msg
    end

    test "message UUID must be unique", %{valid_args: args} do
      {:ok, _msg} = Messages.insert(args)
      {:error, msg} = Messages.insert(args)
      assert "Uuid has already been taken" == msg
    end
  end
end
