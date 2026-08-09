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
    :node_id,
    connected: false,
    subscriptions: %{},
    devices: %{}
  ]

  defmodule DeviceState do
    @moduledoc false
    # `topic` is remembered because a device that got removed can no longer be
    # resolved into the identifier its discovery topic is built from.
    defstruct components: %{}, subscriptions: %{}, topic: nil
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
    Logger.put_application_level(:emqtt, :info)
    Process.flag(:trap_exit, true)

    {:ok,
     %__MODULE__{
       emqtt_opts: config.broker,
       discovery_prefix: config.discovery_prefix,
       node_id: Homex.slug(config.node_id)
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
          node_id: node_id,
          devices: old_devices
        } = state
      ) do
    groups = Homex.descriptors() |> Enum.group_by(& &1.device)
    known_devices = Homex.devices()

    {resolved, unresolved} =
      Map.merge(old_devices, groups)
      |> Map.keys()
      |> Enum.map(&{&1, Map.get(known_devices, &1)})
      |> Enum.split_with(fn {_id, device} -> device end)

    for {device_id, nil} <- unresolved do
      Logger.warning(
        "device #{inspect(device_id)} is not registered, not publishing its entities"
      )

      old_state = Map.get(old_devices, device_id, %DeviceState{})

      for topic <- Map.keys(old_state.subscriptions) do
        :emqtt.unsubscribe(emqtt_pid, topic)
      end

      # clearing the retained discovery config makes Home Assistant drop the device
      if old_state.topic do
        :emqtt.publish(emqtt_pid, old_state.topic, "", retain: true)
      end
    end

    devices =
      Enum.reduce(resolved, %{}, fn {device_id, device}, acc ->
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

        device_config = device_config(node_id, known_devices, device)

        discovery_config = %{
          device: device_config,
          origin: Homex.origin(),
          components: Map.merge(tombstones, new_state.components)
        }

        payload = Homex.encode!(discovery_config)

        topic = build_discovery_config_topic(discovery_prefix, device_config)

        with :ok <- :emqtt.publish(emqtt_pid, topic, payload, retain: true) do
          Logger.debug("published discovery config")
        end

        Map.put(acc, device_id, %{new_state | topic: topic})
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

  # HA identifies a device by its identifiers, so they are scoped by the node id —
  # unique per homex instance, stable across renames of the device itself.
  defp identifier(node_id, %Homex.Device{id: id}), do: "homex-#{node_id}-#{id}"

  @doc false
  @spec device_config(String.t(), %{Homex.Device.id() => Homex.Device.t()}, Homex.Device.t()) ::
          map()
  def device_config(node_id, devices, %Homex.Device{} = device) do
    %{
      name: device.name,
      identifiers: [identifier(node_id, device)],
      manufacturer: device.manufacturer,
      model: device.model,
      serial_number: device.serial_number,
      sw_version: device.sw_version,
      hw_version: device.hw_version,
      via_device: build_via_device(node_id, devices, device)
    }
    |> Map.reject(fn {_key, val} -> is_nil(val) end)
  end

  defp build_via_device(_node_id, _devices, %Homex.Device{via: nil}), do: nil

  defp build_via_device(node_id, devices, %Homex.Device{via: via}) do
    case Map.fetch(devices, via) do
      {:ok, parent} ->
        identifier(node_id, parent)

      :error ->
        Logger.warning("device #{inspect(via)} referenced by :via is not defined, ignoring")
        nil
    end
  end

  defp build_discovery_config_topic(discovery_prefix, device_config) do
    "#{discovery_prefix}/device/#{hd(device_config.identifiers)}/config"
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
