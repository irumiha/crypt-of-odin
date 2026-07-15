# Chapter 8 — God Mode and Headless Worlds

Game state at the end of this chapter: F1 opens a debug mode with
collider visualization, an entity inspector on the mouse cursor,
noclip, teleport-to-cursor, spawn-at-cursor, and time scaling. The
world also gained headless unit tests: the real movement, collision,
contact, and lifecycle code running with no window and no GPU, in CI.

Build and run:

    ./build.sh && ./crypt

Tests:

    odin test tests

## Changes from ch07

| File | Status | Notes |
|------|--------|-------|
| `src/debug.odin` | new | the instrument panel: toggles, collider overlay, cursor inspector (`dump` aimed with the mouse), `rl.GetScreenToWorld2D` |
| `tests/tworld.odin` | new | headless suites: walls (the ch07 autopilot corner run as a regression test, plus the solid-void pin on floor division), contacts/pickups, entity lifecycle |
| `src/tilemap.odin` | changed | testability refactor: `parse_map(ascii)` no longer touches the atlas; looks moved into `Tile_Skin`/`make_skin` |
| `src/systems.odin` | changed | `movement_system` gains a `noclip` parameter (player ignores walls while set) |
| `src/main.odin` | changed | debug wiring (F1/T/E keys, time-scaled dt); `spawn_critter` returns its entity |
| `src/ecs.odin` | unchanged | |
| `src/collision.odin` | unchanged | |
| `src/camera.odin` | unchanged | |
| `src/sprites.odin` | unchanged | |
| `src/input.odin` | unchanged | |
| `src/resources.odin` | unchanged | |
| `assets/` | unchanged | (no `config.nims` equivalent needed: `odin test tests` just works) |
