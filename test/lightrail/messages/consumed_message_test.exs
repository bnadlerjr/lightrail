defmodule Lightrail.MessagesConsumedMessageTest do
  use ExUnit.Case, async: true

  alias Lightrail.Messages.ConsumedMessage

  setup do
    uuid = "deadbeef-dead-dead-dead-deaddeafbeef"

    attrs = %{
      correlation_id: uuid,
      encoded_message: "xyz-gibberish-xyz",
      exchange: "lightrail:test",
      message_type: "TestMessage",
      queue: "lightrail:test:event",
      status: "sent",
      user_uuid: uuid,
      uuid: uuid
    }

    %{uuid: uuid, valid_attrs: attrs}
  end

  describe "status transitions" do
    test "processing -> success" do
      msg = %ConsumedMessage{status: "processing"}
      changeset = ConsumedMessage.transition(msg, "success")
      assert changeset.valid?
      result = Ecto.Changeset.apply_changes(changeset)
      assert "success" == result.status
    end

    test "processing -> failed_to_process" do
      msg = %ConsumedMessage{status: "processing"}
      changeset = ConsumedMessage.transition(msg, "failed_to_process")
      assert changeset.valid?
      result = Ecto.Changeset.apply_changes(changeset)
      assert "failed_to_process" == result.status
    end

    test "failed_to_process -> processing" do
      msg = %ConsumedMessage{status: "failed_to_process"}
      changeset = ConsumedMessage.transition(msg, "processing")
      assert changeset.valid?
      result = Ecto.Changeset.apply_changes(changeset)
      assert "processing" == result.status
    end
  end

  describe "#changeset" do
    test "permitted fields", %{uuid: uuid, valid_attrs: valid_attrs} do
      changeset = ConsumedMessage.changeset(%ConsumedMessage{}, valid_attrs)
      assert changeset.valid?
      msg = Ecto.Changeset.apply_changes(changeset)
      assert uuid == msg.correlation_id
      assert "xyz-gibberish-xyz" == msg.encoded_message
      assert "lightrail:test" == msg.exchange
      assert "TestMessage" == msg.message_type
      assert "lightrail:test:event" == msg.queue
      assert "sent" == msg.status
      assert uuid == msg.user_uuid
      assert uuid == msg.uuid
    end

    test "unpermitted fields are ignored", %{valid_attrs: valid_attrs} do
      attrs = Map.put(valid_attrs, :extra, 42)
      changeset = ConsumedMessage.changeset(%ConsumedMessage{}, attrs)
      assert changeset.valid?
    end

    test "uuid is required", %{valid_attrs: valid_attrs} do
      attrs = Map.delete(valid_attrs, :uuid)
      changeset = ConsumedMessage.changeset(%ConsumedMessage{}, attrs)
      refute changeset.valid?
      assert [uuid: {"can't be blank", [validation: :required]}] == changeset.errors
    end

    test "encoded_message is required", %{valid_attrs: valid_attrs} do
      attrs = Map.delete(valid_attrs, :encoded_message)
      changeset = ConsumedMessage.changeset(%ConsumedMessage{}, attrs)
      refute changeset.valid?

      assert [encoded_message: {"can't be blank", [validation: :required]}] ==
               changeset.errors
    end

    test "message_type is required", %{valid_attrs: valid_attrs} do
      attrs = Map.delete(valid_attrs, :message_type)
      changeset = ConsumedMessage.changeset(%ConsumedMessage{}, attrs)
      refute changeset.valid?

      assert [message_type: {"can't be blank", [validation: :required]}] ==
               changeset.errors
    end

    test "status is required", %{valid_attrs: valid_attrs} do
      attrs = Map.delete(valid_attrs, :status)
      changeset = ConsumedMessage.changeset(%ConsumedMessage{}, attrs)
      refute changeset.valid?

      assert [status: {"can't be blank", [validation: :required]}] ==
               changeset.errors
    end

    test "queue is required", %{valid_attrs: valid_attrs} do
      attrs = Map.delete(valid_attrs, :queue)
      changeset = ConsumedMessage.changeset(%ConsumedMessage{}, attrs)
      refute changeset.valid?

      assert [queue: {"can't be blank", [validation: :required]}] ==
               changeset.errors
    end
  end
end
