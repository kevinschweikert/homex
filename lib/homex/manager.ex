defmodule Homex.Manager do
  @moduledoc """
  Central manager for broker and entities.

  The mananger is responsible to manage the communication with the MQTT broker and keeps track of all registered entities.
  """
  use GenServer

  require Logger

  defstruct [
    :emqtt_pid,
    :emqtt_opts,
    :emqtt_ref,
    :discovery_prefix,
    :device,
    :origin,
    connected: false,
    entities_to_remove: []
  ]

  def start_link(%Homex.Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @type qos() :: 0 | 1 | 2

  @type qos_name() :: :qos0 | :at_most_once | :qos1 | :at_least_once | :qos2 | :exactly_once

  @type pubopt() :: {:retain, boolean()} | {:qos, qos() | qos_name()}

  @spec connected?() :: boolean()
  def connected?, do: GenServer.call(__MODULE__, :is_connected)

  @doc """
  Let's you publish additional messages to a topic
  """
  @spec publish(String.t(), binary() | map(), [pubopt()]) ::
          :ok | {:error, Jason.EncodeError.t() | Exception.t()}

  def publish(topic, payload, opts \\ [])
  def publish(topic, payload, opts) when is_binary(payload), do: do_publish(topic, payload, opts)

  def publish(topic, payload, opts) do
    with {:ok, payload} <- Jason.encode(payload) do
      do_publish(topic, payload, opts)
    end
  end

  defp do_publish(topic, payload, opts),
    do: GenServer.cast(__MODULE__, {:publish, topic, payload, opts})

  def entities do
    DynamicSupervisor.which_children(Homex.EntitySupervisor)
    |> Enum.map(fn {_id, pid, _type, _module} -> GenServer.call(pid, :state) end)
    |> List.flatten()
  end

  @doc """
  Finds an Entity by its name or implementing module.
  """
  @spec entity(module()) :: Entity.t() | nil
  @spec entity(String.t()) :: Entity.t() | nil
  def entity(module) when is_atom(module), do: find_entity(&(&1.impl == module))
  def entity(name) when is_binary(name), do: find_entity(&(&1.impl.name() == name))

  def find_entity(func) when is_function(func, 1), do: Enum.find(entities(), &func.(&1))

  @doc """
  Adds a module to the entities and updates the discovery config, so that Home Assistant also adds this entity.
  """
  @spec add_entity(atom()) :: :ok | {:error, atom()}
  def add_entity(module) when is_atom(module) do
    if Homex.Entity.implements_behaviour?(module) do
      GenServer.call(__MODULE__, {:add_entity, module})
    else
      Logger.error("Can't add entity.Behaviour Homex.Entity missing for #{module}")
      {:error, :entity_behaviour_missing}
    end
  end

  @doc """
  Adds multiple modules to the entities and updates the discovery config, so that Home Assistant also adds the entities.
  Returns a list of started entities.
  """
  @spec add_entities([atom()]) :: [atom()]
  def add_entities(entities) when is_list(entities) do
    if Enum.all?(entities, &Homex.Entity.implements_behaviour?/1) do
      GenServer.call(__MODULE__, {:add_entities, entities})
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
      GenServer.call(__MODULE__, {:remove_entity, module})
    else
      Logger.error("Can't remove entity.Behaviour Homex.Entity missing for #{module}")
      {:error, :entity_behaviour_missing}
    end
  end

  @impl GenServer
  def init(config) do
    emqtt_opts = config.broker
    discovery_prefix = config.discovery_prefix
    device = config.device
    origin = config.origin

    Logger.put_application_level(:emqtt, :info)
    Process.flag(:trap_exit, true)

    {:ok,
     %__MODULE__{
       emqtt_opts: emqtt_opts,
       discovery_prefix: discovery_prefix,
       device: device,
       origin: origin
     }, {:continue, :connect}}
  end

  @impl GenServer
  def handle_continue(:connect, %__MODULE__{emqtt_opts: emqtt_opts} = state) do
    with {:ok, pid} <- :emqtt.start_link(emqtt_opts),
         {:ok, _props} <- :emqtt.connect(pid) do
      Logger.debug("Connected")

      {:noreply, %{state | emqtt_pid: pid, emqtt_ref: Process.monitor(pid), connected: true},
       {:continue, :subscribe_to_topics}}
    else
      {:error, reason} ->
        Logger.error("Failed to connect to MQTT broker: #{inspect(reason)}")
        Process.send_after(self(), :reconnect, 5000)
        {:noreply, state}
    end
  end

  def handle_continue(:subscribe_to_topics, %__MODULE__{emqtt_pid: emqtt_pid} = state) do
    topics =
      Registry.select(Homex.SubscriptionRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

    for topic <- topics do
      :emqtt.subscribe(emqtt_pid, topic)
    end

    {:noreply, state, {:continue, :publish_discovery_config}}
  end

  def handle_continue(:publish_discovery_config, %__MODULE__{emqtt_pid: nil} = state) do
    {:noreply, state}
  end

  def handle_continue(
        :publish_discovery_config,
        %__MODULE__{
          emqtt_pid: emqtt_pid,
          discovery_prefix: discovery_prefix,
          device: device,
          origin: origin,
          entities_to_remove: entities_to_remove
        } = state
      ) do
    {:reply, entities, _} = entities()

    components =
      for entity <- entities, into: %{} do
        {entity.impl.unique_id(), entity.impl.config()}
      end

    components =
      for impl <- entities_to_remove, into: components do
        {impl.unique_id(), %{platform: impl.platform()}}
      end

    discovery_config = %{
      device: device,
      origin: origin,
      components: components
    }

    topic = "#{discovery_prefix}/device/#{Homex.escape(device.name)}/config"

    payload = Jason.encode!(discovery_config)

    with :ok <- :emqtt.publish(emqtt_pid, topic, payload, retain: true) do
      Logger.debug("published discovery config")
    end

    {:noreply, %{state | entities_to_remove: []}}
  end

  @impl GenServer
  def handle_call(:is_connected, _from, %__MODULE__{connected: connected} = state) do
    {:reply, connected, state}
  end

  def handle_call({:add_entity, module}, _from, %__MODULE__{} = state) do
    with {:ok, _pid} <-
           DynamicSupervisor.start_child(Homex.EntitySupervisor, {Homex.Entity, impl: module}) do
      Logger.info("added entity #{module.name()}")

      {:reply, :ok, state, {:continue, :publish_discovery_config}}
    else
      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_call({:add_entities, modules}, _from, %__MODULE__{} = state) do
    started =
      for module <- modules do
        with {:ok, _pid} <-
               DynamicSupervisor.start_child(Homex.EntitySupervisor, {Homex.Entity, impl: module}) do
          Logger.info("added entity #{module.name()}")
          module
        else
          {:error, error} ->
            Logger.info("Failed to start entity #{module.name()}, reason #{inspect(error)}")
            []
        end
      end

    {:reply, List.flatten(started), state, {:continue, :publish_discovery_config}}
  end

  def handle_call(
        {:remove_entity, module},
        _from,
        %__MODULE__{entities_to_remove: entities_to_remove} = state
      ) do
    child =
      DynamicSupervisor.which_children(Homex.EntitySupervisor)
      |> Enum.find({:error, :entity_not_found}, fn {_id, _pid, _type, modules} ->
        module in modules
      end)

    with {_id, pid, _type, _modules} <- child,
         :ok <- DynamicSupervisor.terminate_child(Homex.EntitySupervisor, pid) do
      Logger.info("removed entity #{module.name()}")

      {:reply, :ok, %{state | entities_to_remove: [module | entities_to_remove]},
       {:continue, :publish_discovery_config}}
    else
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  def handle_call(_, _from, %__MODULE__{connected: false} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  @impl GenServer
  def handle_cast(
        {:publish, topic, payload, opts},
        %__MODULE__{emqtt_pid: emqtt_pid, connected: true} = state
      )
      when not is_nil(emqtt_pid) do
    with :ok <- :emqtt.publish(emqtt_pid, topic, payload, opts) do
      Logger.debug("published #{inspect(payload)} to #{topic}")
    end

    {:noreply, state}
  end

  def handle_cast(_, %__MODULE__{connected: false} = state) do
    {:noreply, state}
  end

  # new MQTT message from broker
  @impl GenServer
  def handle_info({:publish, %{topic: topic, payload: payload}}, %__MODULE__{} = state) do
    Logger.debug("Received #{payload} from #{topic}")

    Registry.dispatch(Homex.SubscriptionRegistry, topic, fn registered ->
      for {pid, _value} <- registered do
        send(pid, {topic, payload})
      end
    end)

    {:noreply, state}
  end

  def handle_info(
        {:DOWN, emqtt_ref, :process, _pid, reason},
        %__MODULE__{emqtt_ref: emqtt_ref} = state
      ) do
    Logger.warning("MQTT client down #{inspect(reason)}")
    {:noreply, %{state | connected: false, emqtt_pid: nil}, {:continue, :connect}}
  end

  def handle_info({:DOWN, _, :process, _reason}, state), do: {:noreply, state}

  def handle_info({:EXIT, _pid, _reason}, %__MODULE__{} = state) do
    {:noreply, state}
  end

  def handle_info(:reconnect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  def handle_info({event, _registry, _topic, _pid, _value}, %__MODULE__{emqtt_pid: nil} = state)
      when event in [:register, :unregister] do
    {:noreply, state}
  end

  def handle_info(
        {:register, _registry, topic, _pid, _value},
        %__MODULE__{emqtt_pid: emqtt_pid} = state
      ) do
    :emqtt.subscribe(emqtt_pid, topic)
    Logger.debug("Subscribed to #{topic}")
    {:noreply, state}
  end

  def handle_info(
        {:unregister, _registry, topic, _pid},
        %__MODULE__{emqtt_pid: emqtt_pid} = state
      ) do
    :emqtt.unsubscribe(emqtt_pid, topic)
    Logger.debug("Unsubscribed from #{topic}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, %__MODULE__{emqtt_pid: emqtt_pid, emqtt_ref: emqtt_ref}) do
    if emqtt_pid && Process.alive?(emqtt_pid), do: :emqtt.disconnect(emqtt_pid)
    if is_reference(emqtt_ref), do: Process.demonitor(emqtt_ref)
  end
end
