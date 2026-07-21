# Chapter 3 — Textures, Sprites, and an Atlas

Game state at the end of this chapter: a tiled crypt floor, a chest, a
skull, a spinning coin, and an idling knight, all real pixel art drawn
from one texture atlas at 2× scale.

Build and run:

    ./build.sh && ./crypt

## Changes from ch02

| File | Status | Notes |
|------|--------|-------|
| `src/art.odin` | new | the game's art, typed in — the subset of ch17's strips this chapter's code actually asks for, plus `chest_empty_open_anim` (this chapter's demo prop only; dropped from later chapters) |
| `src/resources.odin` | new | `Atlas`: texture + name→Rectangle index built by `build_atlas` from the typed strips in `art.odin`; `atlas_rect`/`atlas_frames` lookups (frame lists cached, shared); `destroy_atlas` |
| `src/sprites.odin` | new | `Anim_Sprite` (accumulator-pattern animation) + static/animated draw procs |
| `src/main.odin` | changed | title scene retired; floor grid rolled once at startup, props, knight |
| `src/embers.odin` | removed | served the title scene |
| `tour.odin` | removed | Chapter 2 material |
| `assets/` | removed | the atlas is typed art now, not a pack on disk |
