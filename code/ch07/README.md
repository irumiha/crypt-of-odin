# Chapter 7 — Collisions

Game state at the end of this chapter: walls are solid. The knight
stops at masonry and slides along it, critters ricochet off the actual
architecture (and can no longer wander into the void), and the knight
collects coins by walking into them. A coin counter joins the HUD.

Build and run:

    ./build.sh && ./crypt

## Changes from ch06

| File | Status | Notes |
|------|--------|-------|
| `src/collision.odin` | new | `overlaps_solid` (the tile grid as its own spatial index), floor-division `tile_coord` (negative space stays solid), and axis-separated `move_and_slide` with flush snapping |
| `src/ecs.odin` | changed | components added: `Collider` (offset/size/layer/hits) and `.Bounce` tag; `Layer` enum; `contacts` frame scratch; `has`, `collider_rect`, `feet_collider` helpers; `dump` extended |
| `src/systems.odin` | changed | `movement_system` now moves-and-slides collider entities (and reflects `.Bounce`); + `contact_system` (layer-filtered O(n²) pairs), + `pickup_system`; old screen-bounds `bounce_system` removed |
| `src/main.odin` | changed | knight and critters get colliders (feet boxes), coins get pickup colliders, coin counter in the HUD |
| `src/tilemap.odin` | unchanged | |
| `src/camera.odin` | unchanged | |
| `src/sprites.odin` | unchanged | |
| `src/input.odin` | unchanged | |
| `src/art.odin` | unchanged | |
| `src/resources.odin` | unchanged | |
