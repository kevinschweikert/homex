defmodule MySwitch do
  use Homex.Entity.Switch, name: "my-switch", update_interval: 10_000

  def handle_on(state) do
    IO.puts("Switch turned on")
    {:noreply, state}
  end

  def handle_off(state) do
    IO.puts("Switch turned off")
    {:noreply, state}
  end

  def handle_update(state) do
    {:reply, [state: Enum.random([on(), off()])], state}
  end
end

defmodule MyTemperature do
  use Homex.Entity.Sensor,
    name: "my-temperature",
    unit_of_measurement: "C",
    device_class: "temperature"

  def handle_update(state) do
    {:reply, [state: Enum.random(-40..40//1)], state}
  end
end

defmodule MyHumidity do
  use Homex.Entity.Sensor,
    name: "my-humidiy",
    unit_of_measurement: "%",
    device_class: "humidity"

  def handle_update(state) do
    {:reply, [state: Enum.random(20..90//1)], state}
  end
end

defmodule MyLight do
  use Homex.Entity.Light, name: "my-light"

  @impl true
  def handle_init(entity) do
    {:ok, entity |> set_on() |> set_brightness(50)}
  end
end
