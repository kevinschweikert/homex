defmodule Homex.Manager do
  @moduledoc """
  Central manager for broker and entities.

  The mananger is responsible to manage the communication with the MQTT broker and keeps track of all registered entities.
  """
  use Tortoise311.Handler

  require Logger

  defstruct [
    :discovery_prefix,
    :device,
    :origin,
    connected: false,
    entities: [],
    entities_to_remove: []
  ]

  def start_link(%Homex.Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @type qos() :: 0 | 1 | 2

  @type qos_name() :: :qos0 | :at_most_once | :qos1 | :at_least_once | :qos2 | :exactly_once

  @type pubopt() :: {:retain, boolean()} | {:qos, qos() | qos_name()}

  @spec connected?() :: boolean()
  def connected? do
    GenServer.call(__MODULE__, :is_connected)
  end

  @doc """
  Let's you publish additional messages to a topic
  """
  @spec publish(String.t(), binary() | map(), [pubopt()]) ::
          :ok | {:error, Jason.EncodeError.t() | Exception.t()}

  def publish(topic, payload, opts \\ [])

  def publish(topic, payload, opts) when is_binary(payload) do
    do_publish(topic, payload, opts)
  end

  def publish(topic, payload, opts) do
    with {:ok, payload} <- Jason.encode(payload) do
      do_publish(topic, payload, opts)
    end
  end

  defp do_publish(topic, payload, opts) do
    Tortoise311.publish_sync(Homex.Client, topic, payload, opts)
  end

  @doc """
  Adds a module to the entities and updates the discovery config, so that Home Assistant also adds this entity.
  """
  @spec add_entity(atom()) :: :ok | {:error, atom()}
  def add_entity(module) when is_atom(module) do
    if Homex.Entity.implements_behaviour?(module) do
      with {:ok, _pid} <- DynamicSupervisor.start_child(Homex.EntitySupervisor, module) do
        Logger.info("added entity #{module.name()}")
        publish_discovery_config(discovery_prefix, device, origin)
        :ok
      end
    else
      Logger.error("Can't add entity.Behaviour Homex.Entity missing for #{module}")
      {:error, :entity_behaviour_missing}
    end
  end

  @doc """
  Adds multiple modules to the entities and updates the discovery config, so that Home Assistant also adds the entities.
  Returns a list of started modules.
  """
  @spec add_entities([atom()]) :: [atom()]
  def add_entities(entities) when is_list(entities) do
    if Enum.all?(entities, &Homex.Entity.implements_behaviour?/1) do
      for module <- entities do
        with {:ok, _pid} <- DynamicSupervisor.start_child(Homex.EntitySupervisor, module) do
          Logger.info("added entity #{module.name()}")
          module
        else
          {:error, error} ->
            Logger.info("Failed to start entity #{module.name()}, reason #{inspect(error)}")
            []
        end
      end

      publish_discovery_config(discovery_prefix, device, origin)
    else
      Logger.error("Can't add entity.Behaviour Homex.Entity missing for one or more modules")
      {:error, :entity_behaviour_missing}
    end
  end

  @doc """
  Removes a registered module from the entities and updates the discovery config, so that Home Assistant also removes this entity.
  """
  @spec remove_entity(atom()) :: :ok | {:error, atom()}
  def remove_entity(module) when is_atom(module) do
    if Homex.Entity.implements_behaviour?(module) do
      child =
        DynamicSupervisor.which_children(Homex.EntitySupervisor)
        |> Enum.find({:error, :entity_not_found}, fn {_id, _pid, _type, modules} ->
          module in modules
        end)

      with {_id, pid, _type, _modules} <- child,
           :ok <- DynamicSupervisor.terminate_child(Homex.EntitySupervisor, pid) do
        Logger.info("removed entity #{module.name()}")

        publish_discovery_config(discovery_prefix, device, origin, [
          {module.unique_id(), %{platform: module.platform()}}
        ])
      end
    else
      Logger.error("Can't remove entity.Behaviour Homex.Entity missing for #{module}")
      {:error, :entity_behaviour_missing}
    end
  end

  @impl Tortoise311.Handler
  def init(config) do
    discovery_prefix = config.discovery_prefix
    device = config.device
    origin = config.origin

    {:ok,
     %__MODULE__{
       discovery_prefix: discovery_prefix,
       device: device,
       origin: origin
     }}
  end

  @impl Tortoise311.Handler
  def connection(:up, %__MODULE__{} = state) do
    Logger.info("connected")

    topics =
      Registry.select(Homex.SubscriptionRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

    next_actions =
      for topic <- topics do
        {:subscribe, topic, qos: 1, timeout: 5_000}
      end

    {:ok, state, next_actions}
  end

  def handle_message(topic, payload, state) do
    topic = Enum.join(topic, "/")

    Registry.dispatch(Homex.SubscriptionRegistry, topic, fn registered ->
      for {pid, _value} <- registered do
        send(pid, {topic, payload})
      end
    end)

    {:ok, state}
  end

  def publish_discovery_config(discovery_prefix, device, origin, to_remove \\ []) do
    entities =
      DynamicSupervisor.which_children(Homex.EntitySupervisor)
      |> Enum.map(fn {_id, _pid, _type, modules} -> modules end)
      |> List.flatten()

    components =
      for module <- entities, into: %{} do
        {module.unique_id(), module.config()}
      end

    discovery_config = %{
      device: device,
      origin: origin,
      components: components ++ to_remove
    }

    topic =
      "#{discovery_prefix}/device/#{Homex.escape(device.name)}/config"

    publish(topic, discovery_config, retain: true)
  end
end
