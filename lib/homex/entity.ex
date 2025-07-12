defmodule Homex.Entity do
  @moduledoc """
  Defines the behaviour and struct for an entity implementation
  """

  @type t() :: %__MODULE__{
          keys: MapSet.t(),
          values: map(),
          handlers: map(),
          changes: map(),
          private: map()
        }

  defstruct values: %{}, changes: %{}, handlers: %{}, keys: MapSet.new(), private: %{}

  @doc false
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc false
  @spec register_handler(t(), atom(), fun(), term()) :: t()
  def register_handler(
        %__MODULE__{keys: keys, values: values, handlers: handlers} = entity,
        key,
        handler_fn,
        initial_value \\ nil
      )
      when is_atom(key) and is_function(handler_fn) do
    values = Map.put(values, key, initial_value)
    handlers = Map.put(handlers, key, handler_fn)
    keys = MapSet.put(keys, key)

    %{entity | keys: keys, values: values, handlers: handlers}
  end

  @doc false
  @spec put_change(t(), atom(), term()) :: t()
  def put_change(%__MODULE__{keys: keys, changes: changes} = entity, key, value)
      when is_atom(key) do
    if key in keys do
      changes = Map.put(changes, key, value)
      %{entity | changes: changes}
    else
      {:error, :badkey}
    end
  end

  @doc false
  @spec execute_change(t()) :: t()
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

  @doc """
  Puts a value into the Entity struct to retrieve it later. Can be used as a key-value store for user data
  """
  @spec put_private(t(), atom(), term()) :: t()
  def put_private(%__MODULE__{private: private} = entity, key, value) when is_atom(key) do
    private = Map.put(private, key, value)
    %{entity | private: private}
  end

  @doc """
  Gets the value from the Entity struct
  """
  @spec get_private(t(), atom()) :: term()
  def get_private(%__MODULE__{private: private}, key) when is_atom(key) do
    Map.get(private, key)
  end

  @doc false
  def execute_from_init(%__MODULE__{} = entity) do
    {:ok, execute_change(entity)}
  end

  def execute_from_init({:ok, %__MODULE__{} = entity}) do
    {:ok, execute_change(entity)}
  end

  def execute_from_init({:error, reason}) do
    {:stop, reason}
  end

  def execute_from_init(_) do
    {:stop, :unknown}
  end

  @doc false
  def execute_from_handle_info(%__MODULE__{} = entity, _) do
    {:noreply, execute_change(entity)}
  end

  def execute_from_handle_info({:noreply, %__MODULE__{} = entity}, _) do
    {:noreply, execute_change(entity)}
  end

  def execute_from_handle_info({:error, reason}, entity) do
    {:stop, reason, entity}
  end

  def execute_from_handle_info(_, entity) do
    {:stop, :unknown, entity}
  end

  @doc "The escaped name of the entity"
  @callback entity_id() :: String.t()

  @doc "The unique id of the entity"
  @callback unique_id() :: String.t()

  @doc "The list of topics to subscribe to"
  @callback subscriptions() :: [String.t()]

  @doc "The Home Assistant component config definition"
  @callback config() :: map()

  @doc "The Home Assistant platform"
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
