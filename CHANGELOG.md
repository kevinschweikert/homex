# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - Unreleased

See [MIGRATION.md](MIGRATION.md) for a step-by-step upgrade guide.

### Added

- `Homex.Adapter` behaviour — transports are now pluggable. The MQTT logic
  (emqtt lifecycle, discovery publishing, wire serialization) moved from
  `Homex.Manager` into `Homex.Adapter.MQTT`
- `Homex.Descriptor` — a transport-neutral description of every entity;
  adapters render it into their wire format
- Runtime entity construction: entities no longer require a dedicated module.
  Specs can be `MySwitch`, `{MySwitch, name: "other"}` (several instances of
  one module) or `{Homex.Entity.Switch, name: "relay", handler: MyHandlers}`
- `handler:` option on every platform — a plain module implementing the
  optional callbacks (`handle_on/1`, `handle_press/1`, ...)
- `Homex.Entity.Handler` behaviour — the platform-independent callbacks
  (`handle_init/1` and the OTP passthroughs `handle_info/2`, `handle_call/2`,
  `handle_cast/2`), so handler implementations can be checked with `@impl`
- `Homex.Entity.snapshot/1` returns the current values of an entity;
  `Homex.descriptors/0` lists all running entities
- Entity fields are typed `state` or `event`: event fields (button press,
  device trigger) publish on every fire instead of being deduplicated, so
  repeated triggers are no longer swallowed
- `Homex.Entity.Platform.using_helper/3` — third-party platforms get the
  `use` sugar in one line

### Changed (breaking)

- Configuration moved from the application environment to supervision-tree
  options: `{Homex, broker: [...], entities: [...]}`. `config :homex, ...` is
  no longer read
- Entity values are typed (`true`/`false`, numbers) instead of wire strings
  (`"ON"`/`"OFF"`); adapters serialize at the edge
- `update_interval` option and `handle_timer/1` callback removed — start a
  timer in `handle_init/1` and react in `handle_info/2`
- `unique_id` now derives from the device identity plus entity kind and name,
  so entities from two machines no longer collide on one broker (#34). Home
  Assistant will treat existing entities as new ones after the upgrade — and
  since the default device identity derives from the hostname, a hostname
  change re-identifies them too; set `device: [identifiers: [...]]` to pin it
- Entity modules are plain handler modules; the GenServer lives in the core
- `MyTrigger.trigger()` is now `Homex.Entity.DeviceTrigger.trigger("my-name")`
- Entities are addressed by their `name` string (e.g. in `Homex.notify/2`),
  not by module

## [0.1.2] - 2026-07-01

### Fixed

- Start `SubscriptionRegistry` before `Manager` so a fast broker connect can no longer crash the supervision tree with an `unknown registry` error
- Button entity referenced an undefined `@action`; use the `@payload_press` module attribute instead

## [0.1.1] - 2026-02-24

### Added

- DeviceTrigger entity
- Button entity

### Fixed

- Entity values were lost if they were not in the changes map
- device defaults overriding values set in options

## [0.1.0] - 2025-11-30

Initial Release
