# Chapter 9 — Enemies and Melee Combat

Game state at the end of this chapter: the critters are enemies. They
wander until the knight gets close, then chase; touching him costs a
hit point, stuns briefly, and knocks him back (with i-frames so it
stays fair). The knight swings a sword (Space or J) that damages and
knocks back enemies; the dead leave skulls. HP, coins, and kills on
the HUD. New combat behavior ships with new headless tests.

Build and run:

    ./build.sh && ./crypt

Tests:

    odin test tests

## Changes from ch08

| File | Status | Notes |
|------|--------|-------|
| `tests/tcombat.odin` | new | damage/i-frames/knockback/death suites, plus enemy AI chase and hysteresis |
| `src/ecs.odin` | changed | components added: `Health` (hp + invuln + stun timers), `Ai` (state enum, chase speed, aggro), `Contact_Damage` (amount + knockback); `.Player_Attack` layer; `dump` extended |
| `src/systems.odin` | changed | + `ai_system` (wander/chase with slack), + `health_system`, + `damage_system` (contacts → hp/i-frames/stun/knockback), + `death_system` (returns where things fell; GPU-free); input waits while stunned |
| `src/input.odin` | changed | `.Attack` action (Space/J) and `was_pressed` |
| `src/sprites.odin` | changed | `make_static_sprite` for one-frame sprites (sword, skull), sharing the atlas cache via `atlas_static` |
| `src/art.odin` | changed | + `weapon_knight_sword`, + `skull` |
| `src/resources.odin` | changed | `atlas_static`: cached one-frame lists (Nim allocated per sprite and let the GC own it; here the atlas owns all frame lists); atlas built from `art.odin` (`build_atlas`) instead of loaded from a PNG pack + index file |
| `src/tilemap.odin` | changed | floor variants `FLOOR_VARIANTS :: 4` (was 8, matching the typed atlas's 4 floor strips) |
| `src/main.odin` | changed | enemy archetype table (`Enemy_Stats.scale`, 2 for the ogre), `spawn_enemy` bundles, `swing_sword`, death decals, merciful respawn, HUD hp/kills |
| `src/debug.odin` | changed | panel moved below the taller HUD |
| everything else | unchanged | |
