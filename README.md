# Homex

This library aims to bring Elixir (and especially Nerves) closer to Home Assistant. This is a work in progress based on the [initial idea](https://elixirforum.com/t/nerves-home-assistant-integration/70920).

## Example

There is a Livebook example [`example.livemd`](https://livebook.dev/run?url=https://raw.githubusercontent.com/kevinschweikert/homex/refs/heads/main/example.livemd) to get you started!

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `homex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:homex, "~> 0.1.0"}
  ]
end
```

## Configuration

```elixir
import Config

config :homex,
  device: [
    identifiers: ["my device"],
  ],
  origin: [
    name: "homex",
  ]
```

## First Entity

```elixir
defmodule MySwitch do
  use Homex.Entity.Switch, name: "my-switch"

  def handle_on(state) do
    IO.puts("Switch turned on")
    {:noreply, state}
  end

  def handle_off(state) do
    IO.puts("Switch turned off")
    {:noreply, state}
  end

  def handle_update(state) do
    {:reply, Enum.random(["ON", "OFF"]), state}
  end
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/homex>.
