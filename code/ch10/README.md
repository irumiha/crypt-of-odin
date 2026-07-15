# Chapter 10 — Generating the Crypt

Game state at the end of this chapter: every floor is procedurally
generated from a seed (printed at startup; same seed, same crypt): an
Isaac-style grid of screen-sized rooms, each holding enemies, with the
camera locked to the current room and panning on transitions. The
stairs down hide in the deepest room behind gold-sealed doors; the
seal-dissolving flask waits in the second-deepest. Standing on the
stairs descends to a fresh floor with more enemies per room.

Build and run:

    ./build.sh && ./crypt

Tests:

    odin test tests

## Changes from ch09

| File | Status | Notes |
|------|--------|-------|
| `src/dungeon.odin` | new | the generator: seeded room walk (a local `rand.Generator` — nothing else can disturb the dice), BFS depths, doorway carving, seal/unlock, room lookup helpers (floor division in `room_at`, same reason as collision's `tile_coord`) |
| `tests/tdungeon.odin` | new | determinism, connectivity, distinct special rooms, seal contract, exactly one staircase |
| `src/tilemap.odin` | changed | tile kinds added: `.Sealed` (gold-tinted wall, solid until unsealed) and `.Stairs`; `init_tilemap` + `set_tile` for generators |
| `src/collision.odin` | changed | sealed tiles are solid |
| `src/ecs.odin` | changed | `Pickup_Kind` (coin/key) component added |
| `src/systems.odin` | changed | `pickup_system` returns what was picked up, not a count; `ai_system` takes the dungeon and scopes aggro to the player's room (distance checks don't respect walls, so enemies used to pile up in doorways) |
| `src/camera.odin` | changed | `camera_follow` takes a pan speed (room transitions use a slower one) |
| `src/main.odin` | changed | generated floors replace the hand-drawn map; room-locked camera targeting; key/seal flow; stairs regenerate the next floor (a visible destroy/rebuild pair — Nim's GC did this behind the curtain) |
| `tests/tworld.odin` | changed | pickup test follows `pickup_system`'s new return type |
| `tests/tcombat.odin` | changed | ai suite runs in a generated crypt; new test: a wall blocks aggro |
| everything else | unchanged | |
