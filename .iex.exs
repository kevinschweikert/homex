defmodule MySwitch do
  use Homex.Entity.Switch, name: "my-switch", update_interval: 10_000

  def handle_on(entity) do
    IO.puts("Switch turned on")
    {:noreply, entity}
  end

  def handle_off(entity) do
    IO.puts("Switch turned off")
    {:noreply, entity}
  end

  def handle_timer(entity) do
    {:noreply, Enum.random([set_on(entity), set_off(entity)])}
  end
end

defmodule MyTemperature do
  use Homex.Entity.Sensor,
    name: "my-temperature",
    unit_of_measurement: Homex.Unit.temperature(:c),
    device_class: "temperature"

  def handle_timer(entity) do
    {:noreply, entity |> set_value(Enum.random(-40..40//1))}
  end
end

defmodule MyHumidity do
  use Homex.Entity.Sensor,
    name: "my-humidiy",
    unit_of_measurement: Homex.Unit.humidity(),
    device_class: "humidity"

  def handle_timer(entity) do
    {:noreply, entity |> set_value(Enum.random(20..90//1))}
  end
end

defmodule MyLight do
  use Homex.Entity.Light, name: "my-light"

  @impl true
  def handle_init(entity) do
    {:ok, entity |> set_on() |> set_brightness(50)}
  end
end
