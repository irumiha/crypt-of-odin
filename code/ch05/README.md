# Chapter 5 — Input and Movement

Game state at the end of this chapter: the knight walks (WASD or
arrows), faces where he's going, and switches between idle and run
animations. The critters inherit the facing and animation polish for
free.

Build and run:

    ./build.sh && ./crypt

## Changes from ch04

| File | Status | Notes |
|------|--------|-------|
| `src/input.odin` | new | the action map: `Action` enum, `BINDINGS` table (multiple keys per action), `is_down`, normalized `move_axis` |
| `src/ecs.odin` | changed | components added: `Actor` (idle/run animation names, + column) and `.Player` (tag, mask-only); `dump` extended |
| `src/systems.odin` | changed | + `player_input_system`, + `actor_anim_system`; `bounce_system` now also clamps positions into bounds |
| `src/sprites.odin` | changed | `Anim_Sprite` tracks its animation name (`set_anim` no-ops when unchanged) and gains `flip_x` (negative source width flip) |
| `src/main.odin` | changed | knight spawns with Velocity/Actor/Player; critters get `Actor`; the critter table spells out animation names (runtime strings need an owner; constants need nobody); schedule grows two systems |
| `src/art.odin` | new | the game's art, typed in — the subset of ch17's strips this chapter's code actually asks for |
| `src/resources.odin` | changed | atlas built from `art.odin` (`build_atlas`) instead of loaded from a PNG pack + index file |
| `assets/` | removed | the atlas is typed art now, not a pack on disk |
