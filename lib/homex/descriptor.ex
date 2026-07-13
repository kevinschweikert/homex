defmodule Homex.Descriptor do
  # TODO: doc
  @type t() :: %__MODULE__{
          kind: atom(),
          fields: %{atom() => :state | :event},
          name: String.t(),
          device: atom(),
          unique_id: String.t() | nil,
          options: Map.t(),
          transport: Map.t()
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
  Overrides the impl's baked-in name with an explicit instance name, so several
  instances of one impl can run side by side. The default name (the impl module
  itself) keeps the descriptor untouched.
  """
  @spec put_instance_name(t(), term()) :: t()
  def put_instance_name(%__MODULE__{} = descriptor, name) when is_binary(name),
    do: %{descriptor | name: name}

  def put_instance_name(%__MODULE__{} = descriptor, _module_default), do: descriptor

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
