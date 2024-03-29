defmodule Test.Support.Message.ContextEntry do
  @moduledoc false
  use Protobuf, map: true, syntax: :proto3

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t()
        }
  defstruct [:key, :value]

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Test.Support.Message do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_uuid: String.t(),
          correlation_id: String.t(),
          uuid: String.t(),
          context: %{String.t() => String.t()},
          info: String.t()
        }
  defstruct [:user_uuid, :correlation_id, :uuid, :context, :info]

  field :user_uuid, 1, type: :string
  field :correlation_id, 2, type: :string
  field :uuid, 3, type: :string
  field :context, 4, repeated: true, type: Test.Support.Message.ContextEntry, map: true
  field :info, 5, type: :string
end
