# Chapter 14 — Game Feel

Game state at the end of this chapter: hits land. Kills burst into
debris (a structure-of-arrays particle system, deliberately outside
the ECS), the screen shakes on impact with a trauma-squared response,
whatever got hurt flashes red, the knight blinks through his i-frames,
and hitstop freezes the simulation for three frames when a blow
connects. All of it hangs off Chapter 12's damage events; combat code
is untouched.

Build and run:

    ./build.sh && ./crypt

Tests:

    odin test tests

## Changes from ch13

| File | Status | Notes |
|------|--------|-------|
| `src/particles.odin` | new | parallel arrays (bodies/life/colors in lockstep), radial `emit_burst`, hot-loop update + swap-pop compaction (`unordered_remove`) across all arrays |
| `tests/tfeel.odin` | new | burst counts, lockstep compaction, drag, trauma clamp/decay, displacement bounds |
| `src/camera.odin` | changed | + `Shake` (trauma-based, squared response, 6 px max) |
| `src/sprites.odin` | changed | animated draw takes a tint |
| `src/systems.odin` | changed | `draw_system`: red hurt-flash while stunned, player blinks at 10 Hz during i-frames |
| `src/main.odin` | changed | hitstop (sim `dt` zeroed briefly on hits), shake wiring, bursts on hits/deaths, shaken camera copy at draw time; the frame delta is capped at 50 ms so a backgrounded window can't hand knockback a whole-tile timestep |
| everything else | unchanged | |
