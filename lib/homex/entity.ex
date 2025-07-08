defmodule Homex.Entity do
  @moduledoc """
  Defines the behaviour for an entity implementation
  """
  @type state() :: term()

  @callback entity_id() :: String.t()
  @callback unique_id() :: String.t()
  @callback subscriptions() :: [String.t()]
  @callback state_topic() :: String.t()
  @callback command_topic() :: String.t()
  @callback config() :: map()
  @callback platform() :: String.t()

  @callback initial_state() :: state()
  @callback handle_update(state()) :: {:noreply, state()} | {:reply, Keyword.t(), state()}
  @callback handle_command(String.t(), state()) ::
              {:noreply, state()} | {:reply, Keyword.t(), state()}

  @callback on() :: String.t()
  @callback off() :: String.t()

  @optional_callbacks command_topic: 0, handle_command: 2, on: 0, off: 0

  @doc """
  Checks if the given module implements the behaviour from this module
  """
  @spec implements_behaviour?(atom()) :: boolean()
  def implements_behaviour?(module) when is_atom(module) do
    attrs = module.__info__(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()
    __MODULE__ in attrs
  end
end
