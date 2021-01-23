defmodule Lightrail.MessageFormat.BinaryProtobufTest do
  use ExUnit.Case, async: true

  alias Lightrail.MessageFormat.BinaryProtobuf
  alias Test.Support.Message

  describe "#encode" do
    test "encode a protobuf" do
      msg = Message.new(uuid: "abc123")

      expected = {
        :ok,
        "{\"encoded_message\":\"GgZhYmMxMjM=\",\"type\":\"Test::Support::Message\"}",
        "Test::Support::Message"
      }

      assert expected == BinaryProtobuf.encode(msg)
    end

    test "only valid protobufs can be encoded" do
      {:error, error} = BinaryProtobuf.encode("foo")
      assert error == "Argument Error: Valid Protobuf required"
    end

    test "bare structs cannot be encoded" do
      {:error, error} = BinaryProtobuf.encode(%{foo: 1})
      assert error == "Argument Error: Valid Protobuf required"
    end
  end

  describe "#decode" do
    test "decode a message to a protobuf" do
      msg = Message.new(uuid: "abc123")
      {:ok, encoded, _type} = BinaryProtobuf.encode(msg)

      expected = {
        :ok,
        %Test.Support.Message{
          context: %{},
          correlation_id: "",
          user_uuid: "",
          uuid: "abc123",
          info: ""
        },
        "Test::Support::Message"
      }

      assert expected == BinaryProtobuf.decode(encoded)
    end

    test "message must be a string" do
      {:error, error} = BinaryProtobuf.decode(:foo)
      assert error == "Malformed JSON given. Must be a string"
    end

    test "message must be valid JSON" do
      {:error, error} = BinaryProtobuf.decode("not_json")
      assert error == "Message is invalid JSON"
    end

    test "message must include a type attribute" do
      {:error, error} = BinaryProtobuf.decode("{}")
      assert error == "Message is missing the `type` attribute"
    end

    test "message protobuf type must be string" do
      message = %{type: 1} |> Jason.encode!()
      {:error, error} = BinaryProtobuf.decode(message)
      assert error == "Message `type` attribute must be a string"
    end

    test "message protobuf module must be defined" do
      message = %{type: "NotAModule"} |> Jason.encode!()
      {:error, error} = BinaryProtobuf.decode(message)
      assert error == "The module is not defined"
    end

    test "enclosed encoded message must be a decodable protobuf" do
      message =
        %{type: "Test.Support.Message", encoded_message: "invalid"}
        |> Jason.encode!()

      {:error, error} = BinaryProtobuf.decode(message)
      assert error == "Cannot decode protobuf"
    end
  end
end
