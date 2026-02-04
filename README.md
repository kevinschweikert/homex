# Homex

[![CI](https://github.com/kevinschweikert/homex/actions/workflows/ci.yml/badge.svg)](https://github.com/kevinschweikert/req/actions/workflows/ci.yml)
[![License](https://img.shields.io/hexpm/l/homex.svg)](https://github.com/kevinschweikert/homex/blob/main/LICENSE)
[![Version](https://img.shields.io/hexpm/v/homex.svg)](https://hex.pm/packages/homex)
[![Hex Docs](https://img.shields.io/badge/documentation-gray.svg)](https://hexdocs.pm/homex)

This library aims to bring Elixir (and especially Nerves) closer to Home Assistant. This is a work in progress based on the [initial idea](https://elixirforum.com/t/nerves-home-assistant-integration/70920).

## Example

There is a Livebook example [`example.livemd`](https://livebook.dev/run?url=https://raw.githubusercontent.com/kevinschweikert/homex/refs/heads/main/example.livemd) to get you started! There is also an example repository using Nerves at https://github.com/kevinschweikert/Homex-Nerves-Example

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `homex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:homex, "~> 0.1.0"},
    # If you want to use the MQTT library without QUIC support add
    # {:emqtt, github: "emqx/emqtt.git", tag: "1.14.7", override: true, system_env: [{"BUILD_WITHOUT_QUIC", "1"}]}  ]
end
```

## Usage

Supported entity types:

- Sensor
- Switch
- Light
- Camera
- Button
- DeviceTrigger

Define a module for the type of entity you want to use

```elixir
defmodule MySwitch do
  use Homex.Entity.Switch, name: "my-switch"

  def handle_on(entity) do
    IO.puts("Switch turned on")
    entity
  end

  def handle_off(entity) do
    IO.puts("Switch turned off")
    entity
  end
end
```

Configure broker and entities. See `Homex.Config` module docs for options.
Entities can also be added/removed at runtime with `Homex.add_entity/1` or `Homex.remove_entity/1`.

```elixir
import Config

config :homex,
  broker: [host: "localhost", port: 1883, username: "admin", password: "admin"],
  entities: [MySwitch]
```

Add `homex` to you supervision tree

```elixir
defmodule MyApp.Application do

  def start(_type, _args) do
    children =
      [
        ...,
        Homex,
        ...
      ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Contribution

PRs and Feedback are very welcome!

## Acknowledgements and Inspiration

- [ex_homeassistant](https://github.com/Reimerei/ex_homeassistant) by @Reimerei
- [hap](https://github.com/mtrudel/hap) by @mtrudel
