# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
