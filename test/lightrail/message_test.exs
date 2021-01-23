defmodule Lightrail.MessageTest do
  use ExUnit.Case, async: true

  alias Lightrail.Message
  alias Lightrail.MessageFormat.BinaryProtobuf
  alias Test.Support.Message, as: Proto

  describe "#prepare_for_publishing" do
    test "returns the encoded protobuf" do
      uuid = "deadbeef-dead-dead-dead-deaddeafbeef"
      msg = Proto.new(uuid: uuid, correlation_id: uuid)
      {:ok, encoded, type} = Message.prepare_for_publishing(msg)

      expected =
        ~s({\"encoded_message\":) <>
          ~s(\"EiRkZWFkYmVlZi1kZWFkLWRlYWQtZGVhZC1kZWFkZGVhZmJlZWYaJGRlY) <>
          ~s(WRiZWVmLWRlYWQtZGVhZC1kZWFkLWRlYWRkZWFmYmVlZg==\",) <>
          ~s(\"type\":\"Test::Support::Message\"})

      assert expected == encoded
      assert "Test::Support::Message" == type
    end

    test "doesn't override message or correlation UUID's if present" do
      uuid = "deadbeef-dead-dead-dead-deaddeafbeef"
      msg = Proto.new(uuid: uuid, correlation_id: uuid)
      {:ok, encoded, _type} = Message.prepare_for_publishing(msg)
      {:ok, decoded} = BinaryProtobuf.decode(encoded)
      assert uuid = decoded.uuid
      assert uuid = decoded.correlation_id
    end

    test "adds a message UUID if one isn't present" do
      msg = Proto.new(info: "this should succeed")
      {:ok, encoded, _type} = Message.prepare_for_publishing(msg)
      {:ok, decoded} = BinaryProtobuf.decode(encoded)
      assert "" != decoded.uuid
    end

    test "adds a correlation UUID if one isn't present" do
      msg = Proto.new(info: "this should succeed")
      {:ok, encoded, _type} = Message.prepare_for_publishing(msg)
      {:ok, decoded} = BinaryProtobuf.decode(encoded)
      assert "" != decoded.correlation_id
    end

    test "doesn't add a user UUID of one isn't present" do
      msg = Proto.new(info: "this should succeed")
      {:ok, encoded, _type} = Message.prepare_for_publishing(msg)
      {:ok, decoded} = BinaryProtobuf.decode(encoded)
      assert "" == decoded.user_uuid
    end
  end

  describe "#decode" do
    test "successfully decode a binary protobuf message" do
      msg = Proto.new(info: "this should succeed")
      {:ok, encoded, _type} = BinaryProtobuf.encode(msg)
      {:ok, proto} = Message.decode(encoded)
      assert proto == msg
    end
  end
end
