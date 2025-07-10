defmodule Homex.Entity do
  @moduledoc """
  Defines the behaviour for an entity implementation
  """
  @type t() :: %__MODULE__{
          keys: MapSet.new(),
          values: map(),
          handlers: map(),
          changes: map(),
          private: nil
        }

  defstruct values: %{}, changes: %{}, handlers: %{}, keys: MapSet.new(), private: nil

  def register_handler(
        %__MODULE__{keys: keys, values: values, handlers: handlers} = entity,
        key,
        handler_fn,
        initial_value \\ nil
      )
      when is_atom(key) do
    values = Map.put(values, key, initial_value)
    handlers = Map.put(handlers, key, handler_fn)
    keys = MapSet.put(keys, key)

    %{entity | keys: keys, values: values, handlers: handlers}
  end

  def put_change(%__MODULE__{keys: keys, changes: changes} = entity, key, value)
      when is_atom(key) do
    if key in keys do
      changes = Map.put(changes, key, value)
      %{entity | changes: changes}
    end
  end

  def execute_change(
        %__MODULE__{keys: keys, values: values, changes: changes, handlers: handlers} = entity
      ) do
    values =
      for key <- keys, into: %{} do
        value = Map.get(values, key)
        change = Map.get(changes, key)
        handler = Map.get(handlers, key)

        if value != change and not is_nil(change) do
          handler.(change)
        end

        {key, change}
      end

    %{entity | changes: %{}, values: values}
  end

  @callback entity_id() :: String.t()
  @callback unique_id() :: String.t()
  @callback subscriptions() :: [String.t()]
  @callback config() :: map()
  @callback platform() :: String.t()

  @doc """
  Checks if the given module implements the behaviour from this module
  """
  @spec implements_behaviour?(atom()) :: boolean()
  def implements_behaviour?(module) when is_atom(module) do
    attrs = module.__info__(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()
    __MODULE__ in attrs
  end
end
