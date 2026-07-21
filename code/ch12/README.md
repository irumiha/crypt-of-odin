# Chapter 12 — HUD and UI

Game state at the end of this chapter: the game presents itself, and
the window is resizable: the fixed 800×450 frame renders offscreen and
blits at the largest integer scale that fits, letterboxed.
Hearts instead of an hp string, icon stats for coins/power/floor/seal,
a minimap built straight from the floor graph (gold = sealed stairs,
outline = you), and floating damage numbers that jump out of whoever
got hurt, drift up, and fade. Damage flows to the UI through a new
`damage_events` frame scratch that Chapter 14's game feel will reuse.

Build and run:

    ./build.sh && ./crypt

Tests:

    odin test tests

## Changes from ch11

| File | Status | Notes |
|------|--------|-------|
| `src/camera.odin` | changed | `adapt_to_dpi` retired; + `Viewport`/`compute_viewport` (integer-scaled letterbox) and `mouse_logical`. The Nim original also hand-built its render target around a naylib framebuffer bug; raylib's plain `LoadRenderTexture` works here, so that workaround never existed |
| `src/debug.odin` | changed | mouse mapping goes through the viewport |
| `src/hud.odin` | new | hearts row (capped at twelve, then a numeral — the row must not march into the minimap), `draw_icon_stat`, minimap from the dungeon's room graph, world-space `draw_floating_texts` |
| `src/ecs.odin` | changed | `.Float_Text` component (+ column, an `i32` — the drawn string is formatted at draw time; Nim stored a GC'd string per popup) |
| `src/systems.odin` | changed | `damage_system` publishes damage events |
| `src/main.odin` | changed | text HUD replaced by `draw_hud`; damage numbers spawned from events (velocity + lifetime reuse the existing systems); two-pass rendering; `Enemy_Stats.scale` (2 for the ogre) |
| `tests/tcombat.odin` | changed | damage events tested (one per hit, none during i-frames) |
| `src/tilemap.odin` | changed | floor variants `FLOOR_VARIANTS :: 4` (was 8, matching the typed atlas's 4 floor strips) |
| `src/art.odin` | changed | + `ui_heart_empty` |
| `src/resources.odin` | changed | atlas built from `art.odin` (`build_atlas`) instead of loaded from a PNG pack + index file |
| everything else | unchanged | |
