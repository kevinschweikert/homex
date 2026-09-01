# Migrating from 0.1 to 0.2

0.2 enables a few missing features which couldn't be done with 0.1. Most of you entity code survives unchanged - what changes is how homex is configured, how entities are constructed, and how timers work.

## 1. Move configuration into your supervision tree

The application environment is no longer read. Pass everything as start
options instead:

```elixir
# before — config/config.exs
config :homex,
  broker: [host: "localhost", port: 1883],
  entities: [MySwitch]

# and in your application
children = [Homex]
```

```elixir
# after — everything at the start site, no config files
children = [
  {Homex, broker: [host: "localhost", port: 1883], entities: [MySwitch]}
]
```

The options themselves (`broker`, `device`, `origin`, `discovery_prefix`,
`entities`) are unchanged — see `Homex.Config`. This enables you to start and configure Homex when and however you like it.

## 2. Replace `update_interval` / `handle_timer`

The built-in timer is gone. Start your own in `handle_init/1` and react in
`handle_info/2` — the message arrives in the entity process and changes are
published automatically:

```elixir
# before
use Homex.Entity.Sensor, name: "my-temperature", update_interval: 10_000

def handle_timer(entity) do
  set_value(entity, Sensor.read())
end
```

```elixir
# after
use Homex.Entity.Sensor, name: "my-temperature"

def handle_init(entity) do
  :timer.send_interval(10_000, :measure)
  entity
end

def handle_info(:measure, entity) do
  set_value(entity, Sensor.read())
end
```

## 3. Fire device triggers by entity name

```elixir
# before
MyTrigger.trigger()

# after
alias Homex.Entity.DeviceTrigger
DeviceTrigger.trigger("my-device-trigger")
```

Entities are addressed by their `name` string everywhere (`Homex.notify/2`,
`Homex.Entity.snapshot/1`, ...), not by module.

## 4. Expect re-created entities in Home Assistant

`unique_id` now includes the device identity (its `identifiers` and `name`),
fixing collisions when two machines expose same-named entities to one broker.
After upgrading, Home Assistant sees your entities as new: history detaches
and per-entity customizations (area, icon, entity id overrides) need to be
reapplied once.

This also means the device identity is now part of every entity's identity.
By default both `identifiers` and `name` derive from the hostname — so a
hostname change re-creates all entities in Home Assistant. If your hostname
isn't stable, pin the identity explicitly:

```elixir
{Homex, device: [identifiers: ["my-device-id"], name: "My Device"], entities: [...]}
```

## 5. Entity values are typed

State is stored as `true`/`false` and numbers instead of wire strings like
`"ON"`. If you inspected `entity.values` or `entity.changes` in callbacks,
match on the typed values. The MQTT wire format is unchanged — adapters
serialize at the edge.

## New in 0.2 (nothing to migrate, worth knowing)

Entities no longer need a dedicated module. All of these are valid entries in
`entities:` (and arguments to `Homex.add_entity/1`):

```elixir
entities: [
  MySwitch,                                                   # as before
  {MySwitch, name: "second-switch"},                          # same module, second instance
  {Homex.Entity.Switch, name: "relay", handler: MyHandlers},  # callbacks in a plain module
  {Homex.Entity.DeviceTrigger, name: "doorbell"}              # no module needed at all
]
```

The `handler` module implements any subset of the platform's optional
callbacks (`handle_init/1`, `handle_on/1`, ...) plus the OTP passthroughs
(`handle_info/2`, `handle_call/2`, `handle_cast/2`).
