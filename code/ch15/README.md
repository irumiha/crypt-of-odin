# Chapter 15 — Shaders: The GPU Joins the Party

Game state at the end of this chapter: two fragment shaders. Hovering
a pickup with the mouse outlines it in gold and names it (a hover
system feeds the draw system through frame scratch, like every other
cross-system handoff), and C toggles a CRT filter — curvature,
scanlines, vignette — applied to the whole frame during the canvas
blit. Shaders ship in two dialects: GLSL 330 for desktop, GLSL 100
twins for the web build, chosen at compile time.

Build and run:

    ./build.sh && ./crypt

Tests:

    odin test tests

## Changes from ch14

| File | Status | Notes |
|------|--------|-------|
| `shaders/*.fs` | new | `outline` and `crt` fragment shaders, each in a 330 and a 100 dialect (next to `src/`: they're code, not art) |
| `src/shaders.odin` | new | `Fx`: loads both shaders (dialect picked by a `when ODIN_ARCH` block), sets the never-changing uniforms once, feeds the per-draw `region` uniform |
| `tests/tshaders.odin` | new | hover pick math; every 330 shader has a 100 twin declaring identical uniforms (`#load_directory` bakes the sources in at compile time) |
| `src/ecs.odin` | changed | + `hovered` frame scratch (slot under the cursor, or −1) — and `make_world` finally has a body: Odin has no field defaults, so the constructor planted in Chapter 4 earns its keep |
| `src/systems.odin` | changed | + `hover_system`; `draw_system` draws the hovered pickup through the outline shader |
| `src/sprites.odin` | changed | + `src_rect` (the current frame's atlas cell, for the outline's region clamp) |
| `src/loot.odin` | changed | + `label` (what the hover UI calls each pickup) |
| `src/input.odin` | changed | + `.Crt` action (C) |
| `src/main.odin` | changed | loads `Fx`, runs the hover system, draws the hover label, wraps the blit in the CRT shader when toggled; `Enemy_Stats.scale` (2 for the ogre) |
| `src/tilemap.odin` | changed | floor variants `FLOOR_VARIANTS :: 4` (was 8, matching the typed atlas's 4 floor strips) |
| `src/resources.odin` | changed | atlas built from `art.odin` (`build_atlas`) instead of loaded from a PNG pack + index file |
| everything else | unchanged | |
