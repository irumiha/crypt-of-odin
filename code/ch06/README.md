# Chapter 6 — Tiles, Rooms, and the Camera

Game state at the end of this chapter: the crypt is a real tilemap
(three rooms and corridors, authored as ASCII art in the source),
bigger than the window, with a camera that eases after the knight and
clamps at the map edges. Nothing collides with anything yet — the
knight ghosts through walls until Chapter 7.

Build and run:

    ./build.sh && ./crypt

## Changes from ch05

| File | Status | Notes |
|------|--------|-------|
| `src/tilemap.odin` | new | `Tile_Kind`/`Tilemap`, ASCII `parse_map`, `tile_at`, `random_floor_pos`, face-vs-top wall rendering via tint; owns the `SCALE`/`TILE_SIZE` consts now |
| `src/camera.odin` | new | `make_camera`, `camera_follow` (dt-scaled easing, clamped to the map), `adapt_to_dpi` (HiDPI displays get the same view) |
| `src/main.odin` | changed | the map string; camera wired into the loop; spawns use `random_floor_pos`; Chapter 3's inline floor grid removed |
| `src/ecs.odin` | unchanged | |
| `src/systems.odin` | unchanged | (`bounce_system` already took bounds as a parameter; it now receives the map's pixel size) |
| `src/sprites.odin` | unchanged | |
| `src/input.odin` | unchanged | |
| `src/art.odin` | new | the game's art, typed in — the subset of ch17's strips this chapter's code actually asks for |
| `src/resources.odin` | changed | atlas built from `art.odin` (`build_atlas`) instead of loaded from a PNG pack + index file |
| `assets/` | removed | the atlas is typed art now, not a pack on disk |
