defmodule Homex.Adapter.ESPHome.EntityProvider do
  @moduledoc false
  @behaviour Espex.EntityProvider

  use GenServer

  alias Homex.Adapter.ESPHome.{Button, Platform, Sensor, Switch}
  alias Homex.Descriptor

  @platforms %{
    switch: Switch,
    sensor: Sensor,
    button: Button
  }

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl Espex.EntityProvider
  def list_entities do
    for {module, descriptor} <- supported(), do: Platform.list_entity(module, descriptor)
  end

  # an entity that exited since the lookup has no snapshot left to advertise, and a
  # button has no state frame at all
  @impl Espex.EntityProvider
  def initial_states do
    for {module, descriptor} <- supported(),
        values = Homex.Entity.snapshot(descriptor.name),
        frame = Platform.state(module, descriptor, values),
        do: frame
  end

  # the entity owns the state, so a command is only delivered to it — the state
  # frame follows from the `:homex, :state` broadcast its commit emits
  @impl Espex.EntityProvider
  def handle_command(%{key: key} = request) do
    with {module, %Descriptor{} = descriptor} <- entity_for_key(key),
         %{} = command <- module.command(request) do
      Homex.Entity.send_command(descriptor.name, command)
    end

    :ok
  end

  def handle_command(_request), do: :ok

  @impl GenServer
  def init(opts) do
    Homex.subscribe()
    {:ok, Keyword.fetch!(opts, :server)}
  end

  @impl GenServer
  def handle_info({:homex, :state, descriptor, values, _changes}, server) do
    if frame = Platform.state(@platforms[descriptor.kind], descriptor, values) do
      Espex.push_state(server, frame)
    end

    {:noreply, server}
  end

  # espex caches `list_entities/0` per connection, so an added or removed entity
  # only reaches a client on reconnect. Nothing to do for `:entities_changed`
  def handle_info(_msg, server), do: {:noreply, server}

  # the entities this adapter can serve, each paired with the platform serving it
  defp supported do
    for %Descriptor{kind: kind} = descriptor <- Homex.descriptors(),
        module = @platforms[kind],
        do: {module, descriptor}
  end

  defp entity_for_key(key) do
    Enum.find(supported(), fn {_module, descriptor} -> Platform.key(descriptor.name) == key end)
  end
end
