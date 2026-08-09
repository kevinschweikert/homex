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

  Only the node id and the entity name go in — they are already unique together,
  since entity names are unique within a node. The device ref is deliberately
  left out so moving an entity between devices keeps its identity in Home
  Assistant instead of re-creating it.
  """
  @spec put_unique_id(t(), String.t()) :: t()
  def put_unique_id(%__MODULE__{name: name} = descriptor, node_id) do
    %{descriptor | unique_id: "#{node_id}-#{Homex.slug(name)}"}
  end
end
