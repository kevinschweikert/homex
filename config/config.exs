import Config

config :homex,
  device: [
    identifiers: ["1234foo_device"],
    name: "Example Device",
    manufacturer: "Elixir",
    model: "Livebook",
    serial_number: "123456789",
    sw_version: "1.0",
    hw_version: "0.1"
  ],
  origin: [
    name: "homex",
    sw_version: "0.1.0",
    support_url: "http://localhost"
  ],
  entities: [MySwitch, MyTemperature, MyHumidity, MyLight]
