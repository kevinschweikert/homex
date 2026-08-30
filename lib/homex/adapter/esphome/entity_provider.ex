defmodule Homex.Adapter.ESPHome.EntityProvider do
  @moduledoc false
  @behaviour Espex.EntityProvider

  use GenServer

  alias Homex.Adapter.ESPHome.{Button, Platform, Sensor, Switch, Light, Camera}
  alias Homex.Descriptor

  @platforms %{
    switch: Switch,
    sensor: Sensor,
    button: Button,
    light: Light,
    camera: Camera
  }

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl Espex.EntityProvider
  def list_entities do
    for {module, descriptor} <- supported(), do: Platform.list_entity(module, descriptor)
  end

  # an entity can exit after the lookup, and a button has no state frame
  @impl Espex.EntityProvider
  def initial_states do
    for {module, descriptor} <- supported(),
        values = Homex.Entity.snapshot(descriptor.name),
        frame = Platform.state(module, descriptor, values),
        do: frame
  end

  # the entity owns the state, so its commit broadcast sends the state frame
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

  # `Reloader` handles `:entities_changed` and `:devices_changed`
  def handle_info(_msg, server), do: {:noreply, server}

  # the entities this adapter can serve, with their platform
  defp supported do
    for %Descriptor{kind: kind} = descriptor <- Homex.descriptors(),
        module = @platforms[kind],
        do: {module, descriptor}
  end

  defp entity_for_key(key) do
    Enum.find(supported(), fn {_module, descriptor} -> Platform.key(descriptor.name) == key end)
  end
end
