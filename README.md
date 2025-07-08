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

## Usage

Define a module for the type of entity you want to use

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
end
```

Configure broker and entities. See `Homex` module docs for options.
Entities can also be added/removed at runtime with `Homex.add_entity/1` or `Homex.remove_enitity/1`.

```elixir
import Config

config :homex,
  emqtt: [host: "localhost", port: 1883],
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

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/homex>.
