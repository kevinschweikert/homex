defmodule MySwitch do
  use Homex.Entity.Switch, name: "my-switch", update_interval: 10_000

  def handle_on(entity) do
    IO.puts("Switch turned on")
    entity
  end

  def handle_off(entity) do
    IO.puts("Switch turned off")
    entity
  end

  def handle_timer(entity) do
    Enum.random([set_on(entity), set_off(entity)])
  end
end

defmodule MyTemperature do
  use Homex.Entity.Sensor,
    name: "my-temperature",
    unit_of_measurement: "°C",
    device_class: "temperature"

  def handle_timer(entity) do
    entity |> set_value(Enum.random(-40..40//1))
  end
end

defmodule MyHumidity do
  use Homex.Entity.Sensor,
    name: "my-humidiy",
    unit_of_measurement: "%",
    device_class: "humidity"

  def handle_timer(entity) do
    entity |> set_value(Enum.random(20..90//1))
  end
end

defmodule MyLight do
  # , modes: [:brightness]
  use Homex.Entity.Light, name: "my-light"

  def handle_init(entity) do
    entity |> set_on() |> set_brightness(50)
  end

  def handle_on(entity) do
    IO.puts("Light turned on")
    entity
  end

  def handle_off(entity) do
    IO.puts("Light turned off")
    entity
  end

  def handle_brightness(entity, brightness) do
    IO.puts("Light at #{brightness}")
    entity
  end
end
