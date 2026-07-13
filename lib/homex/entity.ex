defmodule Homex.Entity do
  @moduledoc """
  Defines the behaviour and struct for an entity implementation
  """
  use GenServer

  @doc "The Home Assistant entity descriptor"
  @callback descriptor() :: Homex.Descriptor.t()

  @doc """
  Configures the intial state for the switch
  """
  @callback handle_init(entity :: t()) :: entity :: t()

  @callback handle_command(cmd :: map(), entity :: t()) :: entity :: t()

  @doc """
  If an `update_interval` is set, this callback will be fired
  """
  @callback handle_timer(entity :: Entity.t()) :: entity :: t()

  @type t() :: %__MODULE__{
          name: term(),
          impl: module(),
          values: map(),
          changes: map(),
          private: map(),
          descriptor: Homex.Descriptor.t()
        }

  defstruct [
    :name,
    :impl,
    :descriptor,
    values: %{},
    changes: %{},
    private: %{}
  ]

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts], generated: true do
      import Homex.Entity
      alias Homex.Entity
      @behaviour Homex.Entity

      @update_interval opts[:update_interval]

      def update_interval, do: @update_interval

      @impl Homex.Entity
      def handle_init(entity), do: entity

      @impl Homex.Entity
      def handle_command(_cmd, entity), do: entity

      @impl Homex.Entity
      def handle_timer(entity), do: entity

      defoverridable handle_init: 1, handle_timer: 1, handle_command: 2
    end
  end

  def via(name), do: {:via, Registry, {Homex.EntityRegistry, name}}
  def via(name, meta), do: {:via, Registry, {Homex.EntityRegistry, name, meta}}

  def child_spec(%__MODULE__{} = entity) do
    %{
      id: {__MODULE__, entity.name},
      start: {__MODULE__, :start_link, [entity]},
      restart: :transient
    }
  end

  def start_link(%__MODULE__{} = entity), do: GenServer.start_link(__MODULE__, entity)

  # TODO: go over this, if this function is still needed
  @doc false
  @spec new(module() | Keyword.t()) :: t() | nil
  def new(module) when is_atom(module), do: new(name: module, impl: module)

  def new(opts) do
    if valid?(opts) do
      struct(__MODULE__, opts)
    else
      nil
    end
  end

  # TODO: go over this, if this function is still needed
  def valid?(%__MODULE__{}), do: true

  def valid?(module) when is_atom(module), do: implements_behaviour?(module)

  def valid?(opts) when is_list(opts) do
    Keyword.has_key?(opts, :name) and Keyword.has_key?(opts, :impl) and
      implements_behaviour?(Keyword.get(opts, :impl))
  end

  def valid?(_), do: false

  def snapshot(name), do: Homex.call(name, {:homex, :snapshot})

  def send_command(name, cmd) do
    Homex.notify(name, {:homex, :command, cmd})
  end

  @doc false
  @spec put_change(t(), atom(), term()) :: t()
  def put_change(
        %__MODULE__{changes: changes, descriptor: %Homex.Descriptor{fields: fields}} = entity,
        key,
        value
      )
      when is_atom(key) do
    if Map.has_key?(fields, key) do
      changes = Map.put(changes, key, value)
      %{entity | changes: changes}
    else
      entity
    end
  end

  @doc false
  @spec execute_change(t()) :: t()
  def execute_change(
        %__MODULE__{
          values: values,
          changes: changes,
          descriptor: %Homex.Descriptor{fields: fields}
        } = entity
      ) do
    diff =
      for {key, value} <- changes, fields[key] == :event or values[key] != value, into: %{} do
        {key, value}
      end

    if map_size(diff) != 0 do
      for {module, instance} <- Homex.adapters() do
        module.publish_state(instance, entity.descriptor, diff)
      end
    end

    %{entity | changes: %{}, values: Map.merge(values, diff)}
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

  @doc """
  Checks if the given module implements the behaviour from this module
  """
  @spec implements_behaviour?(atom()) :: boolean()
  def implements_behaviour?(module) when is_atom(module) do
    attrs = module.__info__(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()
    __MODULE__ in attrs
  end

  @impl GenServer
  def init(%__MODULE__{impl: impl} = entity) do
    case impl.update_interval() do
      :never -> :ok
      time -> :timer.send_interval(time, {:homex, :timer})
    end

    descriptor =
      impl.descriptor()
      |> Homex.Descriptor.put_instance_name(entity.name)
      |> Homex.Descriptor.put_unique_id(Homex.device())

    with {:ok, _pid} <-
           Registry.register(Homex.EntityRegistry, descriptor.name, descriptor) do
      values = Map.new(descriptor.fields, fn {key, _kind} -> {key, nil} end)
      entity = %{entity | descriptor: descriptor, values: values}
      {:ok, entity |> impl.handle_init() |> execute_change()}
    end
  end

  @impl GenServer
  def handle_call({:homex, :snapshot}, _from, entity) do
    {:reply, entity.values, entity}
  end

  # unregistering here is synchronous, unlike the registry cleanup after death
  def handle_call({:homex, :remove}, _from, entity) do
    Registry.unregister(Homex.EntityRegistry, entity.descriptor.name)
    {:stop, :normal, :ok, entity}
  end

  def handle_call(msg, _from, %{impl: impl} = entity) do
    if function_exported?(impl, :handle_call, 2) do
      {reply, entity} = impl.handle_call(msg, entity)
      {:reply, reply, execute_change(entity)}
    else
      {:reply, {:error, :not_handled}, entity}
    end
  end

  @impl GenServer
  def handle_cast(msg, %{impl: impl} = entity) do
    if function_exported?(impl, :handle_cast, 2) do
      entity = impl.handle_cast(msg, entity) |> execute_change()
      {:noreply, entity}
    else
      {:noreply, entity}
    end
  end

  @impl GenServer
  def handle_info({:homex, :timer}, %{impl: impl} = entity) do
    entity = entity |> impl.handle_timer() |> execute_change()
    {:noreply, entity}
  end

  def handle_info({:homex, :command, cmd}, %{impl: impl} = entity) do
    entity = impl.handle_command(cmd, entity) |> execute_change()
    {:noreply, entity}
  end

  # Fallback, passes the info msg along to the implementation for handling
  def handle_info(msg, %{impl: impl} = entity) do
    if function_exported?(impl, :handle_info, 2) do
      entity = impl.handle_info(msg, entity) |> execute_change()
      {:noreply, entity}
    else
      {:noreply, entity}
    end
  end
end
