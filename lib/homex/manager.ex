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
    connected: false,
    subscriptions: [],
    entities: [],
    entities_to_remove: []
  ]

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @type qos() :: 0 | 1 | 2

  @type qos_name() :: :qos0 | :at_most_once | :qos1 | :at_least_once | :qos2 | :exactly_once

  @type pubopt() :: {:retain, boolean()} | {:qos, qos() | qos_name()}

  def status do
    GenServer.call(__MODULE__, :status)
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
    GenServer.cast(__MODULE__, {:publish, topic, payload, opts})
  end

  @spec publish_discovery_config() :: :ok
  def publish_discovery_config() do
    GenServer.cast(__MODULE__, :publish_discovery_config)
  end

  @spec subscribe(String.t() | [String.t()]) :: String.t() | [String.t()]
  defp subscribe(topics) when is_list(topics) do
    for topic <- topics do
      subscribe(topic)
    end
  end

  defp subscribe(topic) when is_binary(topic) do
    GenServer.cast(__MODULE__, {:subscribe, topic})
    topic
  end

  @spec unsubscribe(String.t() | [String.t()]) :: String.t() | [String.t()]
  defp unsubscribe(topics) when is_list(topics) do
    for topic <- topics do
      unsubscribe(topic)
    end
  end

  defp unsubscribe(topic) when is_binary(topic) do
    GenServer.cast(__MODULE__, {:unsubscribe, topic})
    topic
  end

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
  def init(_init_arg \\ []) do
    emqtt_opts = Homex.emqtt_options()
    Logger.put_application_level(:emqtt, :info)
    Process.flag(:trap_exit, true)

    send(self(), :connect)

    {:ok,
     %__MODULE__{
       emqtt_opts: emqtt_opts,
       connected: true
     }}
  end

  @impl GenServer
  def handle_call(:status, _from, %__MODULE__{connected: connected} = state) do
    status = if(connected, do: :connected, else: :disconnected)
    {:reply, status, state}
  end

  def handle_call({:add_entity, module}, _from, %__MODULE__{entities: entities} = state) do
    with {:ok, _pid} <- DynamicSupervisor.start_child(Homex.EntitySupervisor, module) do
      subscribe(module.subscriptions())
      entities = [module | entities]

      publish_discovery_config()
      Logger.info("added entity #{module.entity_id()}")

      {:reply, :ok, %{state | entities: entities}}
    else
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  def handle_call(
        {:remove_entity, module},
        _from,
        %__MODULE__{entities: entities, entities_to_remove: entities_to_remove} = state
      ) do
    child =
      DynamicSupervisor.which_children(Homex.EntitySupervisor)
      |> Enum.find({:error, :entity_not_found}, fn {_id, _pid, _type, modules} ->
        module in modules
      end)

    with {_id, pid, _type, _modules} <- child,
         :ok <- DynamicSupervisor.terminate_child(Homex.EntitySupervisor, pid) do
      unsubscribe(module.subscriptions())
      entities = entities -- [module]

      Logger.info("removed entity #{module.entity_id()}")
      publish_discovery_config()

      {:reply, :ok,
       %{state | entities: entities, entities_to_remove: [module | entities_to_remove]}}
    else
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_cast(
        _,
        %__MODULE__{
          connected: false
        } = state
      ) do
    Logger.warning("MQTT client not connected")
    {:noreply, state}
  end

  def handle_cast(
        :publish_discovery_config,
        %__MODULE__{
          emqtt_pid: emqtt_pid,
          entities: entities,
          entities_to_remove: entities_to_remove
        } = state
      ) do
    components =
      for module <- entities, into: %{} do
        {module.unique_id(), module.config()}
      end

    components =
      for module <- entities_to_remove, into: components do
        {module.unique_id(), %{platform: module.platform()}}
      end

    discovery_config = Homex.discovery_config(components)

    topic =
      "#{Homex.discovery_prefix()}/device/#{Homex.entity_id(discovery_config.device.name)}/config"

    payload = Jason.encode!(discovery_config)

    with :ok <- :emqtt.publish(emqtt_pid, topic, payload, retain: true) do
      Logger.debug("published discovery config")
    end

    {:noreply, %{state | entities_to_remove: []}}
  end

  def handle_cast({:publish, topic, payload, opts}, %__MODULE__{emqtt_pid: emqtt_pid} = state) do
    with :ok <- :emqtt.publish(emqtt_pid, topic, payload, opts) do
      Logger.debug("published #{payload} to #{topic}")
    end

    {:noreply, state}
  end

  def handle_cast(
        {:subscribe, topic},
        %__MODULE__{emqtt_pid: emqtt_pid, subscriptions: subscriptions} = state
      ) do
    with {:ok, _, _} <- :emqtt.subscribe(emqtt_pid, topic) do
      Logger.debug("subscribed to #{topic}")
      {:noreply, %{state | subscriptions: [topic | subscriptions]}}
    else
      _ ->
        {:noreply, state}
    end
  end

  def handle_cast(
        {:unsubscribe, topic},
        %__MODULE__{emqtt_pid: emqtt_pid, subscriptions: subscriptions} = state
      ) do
    with {:ok, _, _} <- :emqtt.unsubscribe(emqtt_pid, topic) do
      Logger.debug("unsubscribed from #{topic}")
      {:noreply, %{state | subscriptions: subscriptions -- [topic]}}
    else
      _ ->
        {:noreply, state}
    end
  end

  def handle_cast(_, %__MODULE__{connected: false} = state) do
    Logger.error("MQTT client not connected!")
    {:noreply, state}
  end

  # new MQTT message from broker
  @impl GenServer
  def handle_info(
        {:publish, %{topic: topic, payload: payload}},
        %__MODULE__{entities: entities} = state
      ) do
    Logger.debug("Received #{payload} from #{topic}")
    for module <- entities, do: send(module, {topic, payload})
    {:noreply, state}
  end

  def handle_info(
        :connect,
        %__MODULE__{emqtt_pid: nil, emqtt_opts: emqtt_opts, subscriptions: subscriptions} = state
      ) do
    {:ok, emqtt_pid} = :emqtt.start_link(emqtt_opts)

    connected = connect(emqtt_pid, subscriptions)

    {:noreply, %{state | emqtt_pid: emqtt_pid, connected: connected}}
  end

  def handle_info(
        :connect,
        %__MODULE__{emqtt_pid: emqtt_pid, subscriptions: subscriptions} = state
      ) do
    connected = connect(emqtt_pid, subscriptions)

    {:noreply, %{state | connected: connected}}
  end

  def handle_info({:connected, _}, state) do
    {:noreply, %{state | connected: true}}
  end

  def handle_info({:EXIT, emqtt_pid, reason}, %__MODULE__{emqtt_pid: emqtt_pid} = state) do
    Logger.warning("MQTT client stopped #{inspect(reason)}")
    {:noreply, %{state | connected: false, emqtt_pid: nil}}
  end

  def handle_info({:disconnected, _, _}, %__MODULE__{} = state) do
    Logger.warning("MQTT client disconnected")
    {:noreply, %{state | connected: false}}
  end

  @spec connect(pid(), [String.t()]) :: boolean()
  defp connect(pid, subscriptions) when is_pid(pid) and is_list(subscriptions) do
    case :emqtt.connect(pid) do
      {:ok, _} ->
        publish_discovery_config()

        for topic <- subscriptions do
          subscribe(topic)
        end

        true

      {:error, _} ->
        Process.send_after(self(), :connect, 10_000)
        false
    end
  end
end
