defmodule Homex.Entity do
  @moduledoc """
  Defines the behaviour for an entity implementation
  """

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
