defmodule Homex.Adapter.MQTT do
  @options_schema [
                    discovery_prefix: [
                      required: false,
                      type: :string,
                      default: "homeassistant",
                      doc:
                        "if changed in Homeassistant you also need to change it here to enable autodiscovery. The default works for a standard installation"
                    ],
                    broker: [
                      required: false,
                      default: [],
                      type: :keyword_list,
                      keys: [
                        host: [
                          type: :string,
                          default: "localhost",
                          doc: "host of the MQTT broker"
                        ],
                        port: [type: :integer, default: 1883, doc: "port of the MQTT broker"],
                        username: [type: :string, doc: "username for the MQTT broker"],
                        password: [type: :string, doc: "passwort for the MQTT broker"]
                      ]
                    ],
                    client_opts: [
                      required: false,
                      default: [],
                      type: :keyword_list,
                      doc:
                        "passed to the MQTT client untouched and merged last, so it can override anything derived from `:broker`. Unvalidated — the accepted keys are the client's, not homex's"
                    ]
                  ]
                  |> NimbleOptions.new!()

  @moduledoc """
  Home Assistant MQTT discovery transport.

  Requires `:emqtt`, which homex does not pull in on its own:

      {:emqtt, "~> 1.14.7"}

  Start it from the `:adapters` option of `Homex`:

      {Homex,
       node_id: Homex.hostname(),
       adapters: [{Homex.Adapter.MQTT, broker: [host: "localhost", port: 1883]}],
       entities: [MySwitch]}

  ## Options

  #{NimbleOptions.docs(@options_schema)}
  """

  use GenServer

  # :emqtt is optional, so its absence is reported by init/1 rather than by the compiler
  @compile {:no_warn_undefined, :emqtt}

  require Logger

  alias Homex.Adapter.MQTT.{Button, Camera, DeviceTrigger, Light, Sensor, Switch, Util}

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

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, NimbleOptions.validate!(opts, @options_schema),
      name: __MODULE__
    )
  end

  def normalize(%Homex.Descriptor{} = descriptor, payload) do
    if mod = platform(descriptor), do: mod.normalize(payload)
  end

  defp platform(%Homex.Descriptor{kind: kind}), do: @platforms[kind]

  # Everything a platform needs for one descriptor. `nil` for an unknown kind, so
  # the callers can use it as a filter.
  defp resolve(node_id, %Homex.Descriptor{} = descriptor) do
    if mod = platform(descriptor) do
      {identifier, topic_builder} = Util.identity(node_id, descriptor)

      topics =
        Map.new(mod.segments(descriptor), fn {key, segments} ->
          {key, topic_builder.(segments)}
        end)

      %{mod: mod, identifier: identifier, topics: topics}
    end
  end

  # Home Assistant reads an explicit null as a value, so empty keys are dropped
  defp compact(map), do: Map.reject(map, fn {_key, val} -> is_nil(val) end)

  @type qos() :: 0 | 1 | 2

  @type qos_name() :: :qos0 | :at_most_once | :qos1 | :at_least_once | :qos2 | :exactly_once

  @type pubopt() :: {:retain, boolean()} | {:qos, qos() | qos_name()}

  @spec connected?() :: boolean()
  def connected?, do: GenServer.call(__MODULE__, :is_connected)

  @impl GenServer
  def init(opts) do
    Code.ensure_loaded?(:emqtt) ||
      raise """
      #{inspect(__MODULE__)} needs the :emqtt dependency, which homex does not pull in on its own. Add it to your deps:

          {:emqtt, "~> 1.14.7"}
      """

    Logger.put_application_level(:emqtt, :info)
    Process.flag(:trap_exit, true)
    Homex.subscribe()

    {:ok,
     %__MODULE__{
       emqtt_opts: emqtt_opts(opts[:broker], opts[:client_opts]),
       discovery_prefix: opts[:discovery_prefix],
       node_id: Homex.node_id()
     }, {:continue, :connect}}
  end

  # TODO: the charlist translation is emqtt's, not MQTT-the-protocol's. Move it
  # into the client wrapper once the client is swappable (#48).
  defp emqtt_opts(broker, client_opts) do
    [
      name: Homex.EMQTT,
      host: String.to_charlist(broker[:host]),
      port: broker[:port],
      username: optional(broker[:username], &String.to_charlist/1),
      password: optional(broker[:password], &String.to_charlist/1)
    ]
    |> Keyword.reject(fn {_key, val} -> is_nil(val) end)
    |> Keyword.merge(client_opts)
  end

  defp optional(nil, _), do: nil
  defp optional(val, transformer), do: transformer.(val)

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
          components: build_components(node_id, entries),
          subscriptions: build_subscriptions(node_id, entries)
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

  defp build_components(node_id, entries) do
    for descriptor <- entries, resolved = resolve(node_id, descriptor), into: %{} do
      %{mod: mod, identifier: identifier, topics: topics} = resolved

      component =
        descriptor
        |> mod.component(topics)
        |> Map.put(:unique_id, identifier)
        |> compact()

      {identifier, component}
    end
  end

  defp build_subscriptions(node_id, entries) do
    for descriptor <- entries,
        resolved = resolve(node_id, descriptor),
        topic <- resolved.mod.subscriptions(descriptor, resolved.topics),
        into: %{} do
      {topic, descriptor}
    end
  end

  @doc false
  @spec device_config(String.t(), %{Homex.Device.id() => Homex.Device.t()}, Homex.Device.t()) ::
          map()
  def device_config(node_id, devices, %Homex.Device{} = device) do
    %{
      name: device.name,
      identifiers: [Util.device_identifier(node_id, device)],
      manufacturer: device.manufacturer,
      model: device.model,
      serial_number: device.serial_number,
      sw_version: device.sw_version,
      hw_version: device.hw_version,
      via_device: build_via_device(node_id, devices, device)
    }
    |> compact()
  end

  defp build_via_device(_node_id, _devices, %Homex.Device{via: nil}), do: nil

  defp build_via_device(node_id, devices, %Homex.Device{via: via}) do
    case Map.fetch(devices, via) do
      {:ok, parent} ->
        Util.device_identifier(node_id, parent)

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
  def handle_info(
        {:homex, :state, %Homex.Descriptor{} = descriptor, values, changes},
        %__MODULE__{node_id: node_id, emqtt_pid: emqtt_pid, connected: true} = state
      )
      when not is_nil(emqtt_pid) do
    if resolved = resolve(node_id, descriptor) do
      opts = [retain: descriptor.transport[:mqtt][:retain]]

      for {topic, payload} <- resolved.mod.publish(descriptor, resolved.topics, values, changes) do
        with :ok <- :emqtt.publish(emqtt_pid, topic, payload, opts) do
          Logger.debug("published #{inspect(payload)} to #{inspect(topic)}")
        end
      end
    end

    {:noreply, state}
  end

  def handle_info({:homex, :state, _, _, _}, state), do: {:noreply, state}

  def handle_info({:homex, event}, state) when event in [:entities_changed, :devices_changed] do
    {:noreply, state, {:continue, :publish_discovery_config}}
  end

  # new MQTT message from broker
  def handle_info(
        {:publish, %{topic: topic, payload: payload}},
        %__MODULE__{subscriptions: subscriptions} = state
      ) do
    Logger.debug("Received #{inspect(payload)} from #{inspect(topic)}")

    # will only yield one descriptor per topic because the topic includes the identifier
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
