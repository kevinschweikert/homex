defmodule Homex.Descriptor do
  # TODO: doc
  @type t() :: %__MODULE__{
          kind: atom(),
          fields: %{atom() => :state | :event},
          name: String.t(),
          device: atom(),
          unique_id: String.t() | nil,
          options: map(),
          transport: map()
        }

  defstruct [
    :kind,
    :fields,
    :name,
    :device,
    :unique_id,
    :options,
    :transport
  ]

  @doc """
  Derives the entity's stable identity and stores it on the descriptor.

  Only identity-bearing fields go into the hash: the root device identity plus
  the descriptor's device ref, kind and name. Everything else (options,
  transport, fields) can change between releases without re-identifying the
  entity in Home Assistant.
  """
  @spec put_unique_id(t(), device :: map()) :: t()
  def put_unique_id(%__MODULE__{} = descriptor, device) do
    unique_id =
      {device[:identifiers], device[:name], descriptor.device, descriptor.kind, descriptor.name}
      |> :erlang.phash2(2 ** 32)
      |> to_string()

    %{descriptor | unique_id: unique_id}
  end
end
