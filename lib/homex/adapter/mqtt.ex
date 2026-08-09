defmodule Homex.Adapter.MQTT do
  use GenServer
  @behaviour Homex.Adapter

  require Logger

  alias Homex.Adapter.MQTT.{Button, Camera, DeviceTrigger, Light, Sensor, Switch}

  @platforms %{
    switch: Switch,
    sensor: Sensor,
    button: Button,
    light: Light,
    camera: Camera,
    device_trigger: DeviceTrigger
  }

  defstruct [
    :emqtt_pid,
    :emqtt_opts,
    :emqtt_ref,
    :discovery_prefix,
    connected: false,
    subscriptions: %{},
    devices: %{}
  ]

  defmodule DeviceState do
    defstruct components: %{}, subscriptions: %{}
  end

  def start_link(%Homex.Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl Homex.Adapter
  def publish_state(instance, %Homex.Descriptor{kind: kind} = desc, changes) do
    case @platforms[kind] do
      nil ->
        :ok

      mod ->
        for {topic, payload} <- mod.publish(desc, changes) do
          GenServer.cast(
            instance,
            {:publish, topic, payload, retain: desc.transport[:mqtt][:retain]}
          )
        end

        :ok
    end
  end

  @impl Homex.Adapter
  def entities_changed(instance), do: GenServer.cast(instance, :entities_changed)

  def component(%Homex.Descriptor{kind: kind} = desc) do
    case @platforms[kind] do
      nil -> :unsupported
      mod -> {:ok, desc |> mod.component() |> Map.reject(fn {_key, val} -> is_nil(val) end)}
    end
  end

  def subscriptions(%Homex.Descriptor{kind: kind} = desc) do
    case @platforms[kind] do
      nil -> []
      mod -> mod.subscriptions(desc)
    end
  end

  def normalize(%Homex.Descriptor{kind: kind}, payload) do
    case @platforms[kind] do
      nil -> nil
      mod -> mod.normalize(payload)
    end
  end

  def topic(%Homex.Descriptor{kind: kind, unique_id: unique_id}, suffix \\ []),
    do: Enum.join(["homex", kind, unique_id | suffix], "/")

  @type qos() :: 0 | 1 | 2

  @type qos_name() :: :qos0 | :at_most_once | :qos1 | :at_least_once | :qos2 | :exactly_once

  @type pubopt() :: {:retain, boolean()} | {:qos, qos() | qos_name()}

  @spec connected?() :: boolean()
  def connected?, do: GenServer.call(__MODULE__, :is_connected)

  @impl GenServer
  def init(config) do
    emqtt_opts = config.broker
    discovery_prefix = config.discovery_prefix

    Logger.put_application_level(:emqtt, :info)
    Process.flag(:trap_exit, true)

    {:ok,
     %__MODULE__{
       emqtt_opts: emqtt_opts,
       discovery_prefix: discovery_prefix
     }, {:continue, :connect}}
  end

  @impl GenServer
  def handle_continue(:connect, %__MODULE__{emqtt_opts: emqtt_opts} = state) do
    with {:ok, pid} <- :emqtt.start_link(emqtt_opts),
         {:ok, _props} <- :emqtt.connect(pid) do
      Logger.debug("Connected")

      {:noreply, %{state | emqtt_pid: pid, emqtt_ref: Process.monitor(pid), connected: true},
       {:continue, :publish_discovery_config}}
    else
      {:error, reason} ->
        Logger.error("Failed to connect to MQTT broker: #{inspect(reason)}")
        Process.send_after(self(), :reconnect, 5000)
        {:noreply, state}
    end
  end

  def handle_continue(:publish_discovery_config, %__MODULE__{emqtt_pid: nil} = state) do
    {:noreply, state}
  end

  def handle_continue(
        :publish_discovery_config,
        %__MODULE__{
          emqtt_pid: emqtt_pid,
          discovery_prefix: discovery_prefix,
          devices: old_devices
        } = state
      ) do
    groups = Homex.descriptors() |> Enum.group_by(& &1.device)
    device_ids = Map.merge(old_devices, groups) |> Map.keys()

    devices =
      Enum.reduce(device_ids, %{}, fn device_id, acc ->
        entries = Map.get(groups, device_id, [])
        old_state = Map.get(old_devices, device_id, %DeviceState{})

        new_state = %DeviceState{
          components: build_components(entries),
          subscriptions: build_subscriptions(entries)
        }

        for topic <- Map.keys(new_state.subscriptions) -- Map.keys(old_state.subscriptions) do
          :emqtt.subscribe(emqtt_pid, topic)
        end

        for topic <- Map.keys(old_state.subscriptions) -- Map.keys(new_state.subscriptions) do
          :emqtt.unsubscribe(emqtt_pid, topic)
        end

        stale_keys = Map.keys(old_state.components) -- Map.keys(new_state.components)
        stale_components = Map.take(old_state.components, stale_keys)

        tombstones =
          Map.new(stale_components, fn {key, val} -> {key, Map.take(val, [:platform])} end)

        discovery_config = %{
          device: build_discovery_config_device(device_id),
          origin: Homex.origin(),
          components: Map.merge(tombstones, new_state.components)
        }

        payload = Homex.encode!(discovery_config)

        topic = build_discovery_config_topic(discovery_prefix, device_id)

        with :ok <- :emqtt.publish(emqtt_pid, topic, payload, retain: true) do
          Logger.debug("published discovery config")
        end

        Map.put(acc, device_id, new_state)
      end)

    subscriptions =
      Enum.reduce(devices, %{}, fn {_device_id, device_state}, acc ->
        Map.merge(acc, device_state.subscriptions)
      end)

    {:noreply, %{state | subscriptions: subscriptions, devices: devices}}
  end

  defp build_components(entries) do
    entries
    |> Enum.reduce(%{}, fn descriptor, acc ->
      case component(descriptor) do
        :unsupported -> acc
        {:ok, comp} -> Map.put(acc, descriptor.unique_id, comp)
      end
    end)
  end

  defp build_subscriptions(entries) do
    for descriptor <- entries, topic <- subscriptions(descriptor), into: %{} do
      {topic, descriptor}
    end
  end

  defp build_discovery_config_device(nil) do
    Homex.device()
  end

  defp build_discovery_config_device(device_id) do
    device = Homex.device()
    devices = Homex.devices()

    %{
      name: devices[device_id].name,
      identifiers: [to_string(device_id)],
      via_device: List.first(device.identifiers)
    }
  end

  defp build_discovery_config_topic(discovery_prefix, device_id) do
    device = Homex.device()
    "#{discovery_prefix}/device/#{Homex.slug(device.name)}-#{device_id || "default"}/config"
  end

  @impl GenServer
  def handle_call(:is_connected, _from, %__MODULE__{connected: connected} = state) do
    {:reply, connected, state}
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
      Logger.debug("published #{inspect(payload)} to #{inspect(topic)}")
    end

    {:noreply, state}
  end

  def handle_cast(:entities_changed, state) do
    {:noreply, state, {:continue, :publish_discovery_config}}
  end

  def handle_cast(_, %__MODULE__{connected: false} = state) do
    {:noreply, state}
  end

  # new MQTT message from broker
  @impl GenServer
  def handle_info(
        {:publish, %{topic: topic, payload: payload}},
        %__MODULE__{subscriptions: subscriptions} = state
      ) do
    Logger.debug("Received #{inspect(payload)} from #{inspect(topic)}")

    # will only yield one descriptor per topic because the topic includes the unique id
    with %Homex.Descriptor{} = descriptor <- subscriptions[topic],
         command when not is_nil(command) <- normalize(descriptor, payload) do
      Homex.Entity.send_command(descriptor.name, command)
    end

    {:noreply, state}
  end

  def handle_info(
        {:DOWN, emqtt_ref, :process, _pid, reason},
        %__MODULE__{emqtt_ref: emqtt_ref} = state
      ) do
    Logger.warning("MQTT client down #{inspect(reason)}")

    {:noreply, %{state | connected: false, emqtt_pid: nil, subscriptions: %{}},
     {:continue, :connect}}
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, state), do: {:noreply, state}

  def handle_info({:EXIT, _pid, _reason}, %__MODULE__{} = state) do
    {:noreply, state}
  end

  def handle_info(:reconnect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  @impl GenServer
  def terminate(_reason, %__MODULE__{emqtt_pid: emqtt_pid, emqtt_ref: emqtt_ref}) do
    if is_pid(emqtt_pid) && Process.alive?(emqtt_pid), do: :emqtt.disconnect(emqtt_pid)
    if is_reference(emqtt_ref), do: Process.demonitor(emqtt_ref)
  end
end
