import Config

config :homeassistant_ex,
  device: %{
    identifiers: ["1234foo_device"],
    name: "Example Device",
    manufacturer: "Elixir",
    model: "Livebook",
    serial_number: "123456789",
    sw_version: "1.0",
    hw_version: "0.1"
  },
  origin: %{
    sw_version: "0.1.0",
    name: "homeassistant_ex",
    support_url: "http://localhost"
  }
