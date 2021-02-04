defmodule Lightrail.MessagesTest do
  use Test.Support.DataCase, async: true

  import Test.Support.Helpers

  alias Lightrail.MessageFormat.BinaryProtobuf
  alias Lightrail.Messages
  alias Lightrail.Messages.ConsumedMessage
  alias Test.Support.Message, as: Proto

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
      persisted = get_published_message!(msg.uuid)
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

  describe "#upsert" do
    setup do
      proto = Proto.new(uuid: UUID.uuid4())
      {:ok, encoded, type} = BinaryProtobuf.encode(proto)

      args = %{
        protobuf: proto,
        type: type,
        exchange: "lightrail:test",
        queue: "lightrail:test:event",
        encoded: encoded
      }

      %{valid_args: args}
    end

    test "valid message is persisted", %{valid_args: args} do
      {:ok, msg} = Messages.upsert(args)
      persisted = get_consumed_message!(msg.uuid)
      assert args.encoded == persisted.encoded_message
      assert "lightrail:test" == persisted.exchange
      assert "lightrail:test:event" == persisted.queue
      assert args.type == persisted.message_type
      assert "processing" == persisted.status
    end

    test "changeset errors are prettified", %{valid_args: args} do
      invalid_args = %{args | type: nil, encoded: nil}
      {:error, msg} = Messages.upsert(invalid_args)
      assert "Encoded message can't be blank, Message type can't be blank" == msg
    end

    test "does an upsert when the status is not 'processing'", %{valid_args: args} do
      msg_one =
        insert_consumed_message!(
          args.protobuf,
          args.encoded,
          args.type,
          args.exchange,
          args.queue,
          "failed_to_process"
        )

      assert_difference row_count("lightrail_consumed_messages"), count: 0 do
        {:ok, msg_two} = Messages.upsert(args)
      end

      assert msg_one.uuid == msg_two.uuid
      assert "processing" == msg_two.status
    end

    test "skipping a message that is already being processed", %{valid_args: args} do
      msg_one =
        insert_consumed_message!(
          args.protobuf,
          args.encoded,
          args.type,
          args.exchange,
          args.queue,
          "processing"
        )

      assert_difference row_count("lightrail_consumed_messages"), count: 0 do
        assert {:skip, msg_one} == Messages.upsert(args)
      end
    end
  end

  describe "#transition_status" do
    setup do
      msg = %ConsumedMessage{
        encoded_message: "message",
        message_type: "type",
        queue: "lightrail:test:event",
        status: "processing",
        uuid: UUID.uuid4()
      }

      insert_consumed_message!(msg)
      %{message: msg}
    end

    test "successfully updates the status", %{message: msg} do
      {:ok, _} = Messages.transition_status(msg, "success")
      persisted = get_consumed_message!(msg.uuid)
      assert "success" == persisted.status
    end

    test "errors are prettified", %{message: msg} do
      {:error, result} = Messages.transition_status(msg, "invalid")

      assert "Status transition_changeset failed: invalid transition from " <>
               "processing to invalid" == result
    end
  end
end
