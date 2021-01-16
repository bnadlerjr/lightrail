defmodule Lightrail.MessageFormat.BinaryProtobuf do
  @moduledoc """
  Messages that use the `BinaryProtobuf` format have the following
  characteristics:

  * The payload s a struct that contains two attributes: `type` and
    `encoded_message`

  * The `type` attribute is the name of the Elixir module for the protobuf
    without the "Elixir" prefix and to use colon notation instead of dots.

  * The `encoded_message` attribute is the encoded protobuf which is then
    Base64 encoded to make it friendly to JSON conversion.

  * The entire payload is then converted to JSON.

  Note:
  I _think_ the reason for converting to colon notation is an artifact of
  wanting to be compatable with the Ruby version since Ruby classes use
  colon notation. -BN

  ## TODO
  * what's the proper convention/formatting for error tuples?

  * I've seen code examples where stacktraces are added to error
    tuples using `__STACKTRACE__`; is that useful here?

  * consider splitting this out into two modules, one for encoding
    and the other for decoding

  * be more explicit about what errors we're rescuing when decoding
    the protobuf

  """

  @doc """
  Encodes `protobuf` in message format.

  Encodes the given `protobuf` by creating a JSON string with two attributes:

  * `type` -- the Protobuf module name as a string using colon notation
  * `encoded_message` -- the Base64 encoded Protobuf

  ## Example

  ```
  iex> msg = Test.Support.Message.new(uuid: UUID.uuid4(), user_uuid: UUID.uuid4(), correlation_id: UUID.uuid4())
  %Test.Support.Message{
    context: %{},
    correlation_id: "73b3c2d3-b3ec-4df8-93c8-f3c0887f5d02",
    user_uuid: "7120dd54-9e00-47c3-85f6-fe11d0b159f5",
    uuid: "3a345c88-f84a-4ceb-b0b3-0e5ce028eea3"
  }

  iex> {:ok, encoded} = Lightrail.MessageFormat.BinaryProtobuf.encode(msg)
  {:ok,
   "{\"encoded_message\":\"CiQ3MTIwZGQ1NC05ZTAwLTQ3YzMtODVmNi1mZTExZDBiMTU5ZjUSJDczYjNjMmQzLWIzZWMtNGRmOC05M2M4LWYzYzA4ODdmNWQwMhokM2EzNDVjODgtZjg0YS00Y2ViLWIwYjMtMGU1Y2UwMjhlZWEz\",\"type\":\"Test::Support::Message\"}"}
  ```

  """
  @spec encode(struct) :: {:ok, String.t()} | {:error, String.t()}
  def encode(protobuf) when is_map(protobuf) or is_atom(protobuf) do
    protobuf
    |> build_payload()
    |> encode_type()
    |> encode_message()
    |> encode_payload_as_json()
  end

  def encode(_), do: {:error, "Argument Error: Valid Protobuf required"}

  @doc """
  Decodes the given `message` into a Protobuf `struct`.

  ## Example

  ```
  iex> msg = Test.Support.Message.new(uuid: UUID.uuid4(), user_uuid: UUID.uuid4(), correlation_id: UUID.uuid4())
  %Test.Support.Message{
    context: %{},
    correlation_id: "73b3c2d3-b3ec-4df8-93c8-f3c0887f5d02",
    user_uuid: "7120dd54-9e00-47c3-85f6-fe11d0b159f5",
    uuid: "3a345c88-f84a-4ceb-b0b3-0e5ce028eea3"
  }

  iex> {:ok, encoded} = Lightrail.MessageFormat.BinaryProtobuf.encode(msg)
  {:ok,
   "{\"encoded_message\":\"CiQ3MTIwZGQ1NC05ZTAwLTQ3YzMtODVmNi1mZTExZDBiMTU5ZjUSJDczYjNjMmQzLWIzZWMtNGRmOC05M2M4LWYzYzA4ODdmNWQwMhokM2EzNDVjODgtZjg0YS00Y2ViLWIwYjMtMGU1Y2UwMjhlZWEz\",\"type\":\"Test::Support::Message\"}"}

  iex> {:ok, decoded} = Lightrail.MessageFormat.BinaryProtobuf.decode(encoded)
  {:ok,
   %Test.Support.Message{
     context: %{},
     correlation_id: "73b3c2d3-b3ec-4df8-93c8-f3c0887f5d02",
     user_uuid: "7120dd54-9e00-47c3-85f6-fe11d0b159f5",
     uuid: "3a345c88-f84a-4ceb-b0b3-0e5ce028eea3"
   }}
  ```

  """
  @spec decode(String.t()) :: {:ok, struct} | {:error, String.t()}
  def decode(message) when not is_binary(message) do
    {:error, "Malformed JSON given. Must be a string"}
  end

  def decode(message) do
    message
    |> decode_json()
    |> parse_type()
    |> check_that_module_is_defined()
    |> decode_protobuf()
  end

  defp build_payload(protobuf), do: {:ok, %{}, protobuf}

  defp encode_type({:ok, payload, protobuf}) do
    type =
      protobuf.__struct__
      |> to_string
      |> replace_invalid_chars()

    {:ok, Map.put(payload, :type, type), protobuf}
  rescue
    KeyError ->
      {:error, "Argument Error: Valid Protobuf required"}
  end

  defp encode_message({:ok, payload, protobuf}) do
    encoded_message =
      protobuf
      |> protobuf.__struct__.encode()
      |> Base.encode64()

    {:ok, Map.put(payload, :encoded_message, encoded_message), protobuf}
  end

  defp encode_message({:error, _} = error), do: error

  defp encode_payload_as_json({:ok, payload, _}), do: Jason.encode(payload)
  defp encode_payload_as_json({:error, _} = error), do: error

  defp parse_type({:ok, %{type: type} = payload}) when is_binary(type) do
    {:ok, Map.put(payload, :module, type_to_module(type))}
  end

  defp parse_type({:ok, %{type: type}}) when not is_binary(type) do
    {:error, "Message `type` attribute must be a string"}
  end

  defp parse_type({:ok, _}), do: {:error, "Message is missing the `type` attribute"}
  defp parse_type({:error, _} = error), do: error

  defp check_that_module_is_defined({:ok, payload}) do
    %{module: module} = payload
    module.__info__(:module)
    {:ok, payload}
  rescue
    UndefinedFunctionError -> {:error, "The module is not defined"}
  end

  defp check_that_module_is_defined({:error, _} = error), do: error

  defp decode_protobuf({:ok, payload}) do
    %{module: module, encoded_message: encoded_message} = payload

    decoded_message =
      encoded_message
      |> Base.decode64!(ignore: :whitespace)
      |> module.decode

    {:ok, decoded_message}
  rescue
    _ -> {:error, "Cannot decode protobuf"}
  end

  defp decode_protobuf({:error, _} = error), do: error

  defp type_to_module(type) do
    type
    |> String.split("::")
    |> Module.concat()
  end

  defp replace_invalid_chars(module_name_string) do
    Regex.replace(~r/\AElixir\./, module_name_string, "")
    |> String.replace(".", "::")
  end

  defp decode_json(json) do
    {:ok, Jason.decode!(json, keys: :atoms)}
  rescue
    Jason.DecodeError -> {:error, "Message is invalid JSON"}
  end
end
