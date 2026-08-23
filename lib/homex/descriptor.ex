defmodule Homex.Descriptor do
  @moduledoc """
  The core definition of an entity. It describes all it's
  features and serves as the canonical representation inside Homex.
  """

  # TODO:
  # evaluate if maybe name should be an atom
  # and also be named entity_id so it mirrors node_id

  @type t() :: %__MODULE__{
          kind: atom(),
          fields: %{atom() => :state | :event},
          name: String.t(),
          device: atom(),
          options: map(),
          transport: map()
        }

  defstruct [
    :kind,
    :fields,
    :name,
    :device,
    :options,
    :transport
  ]
end
