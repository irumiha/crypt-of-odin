# Chapter 16 — The Boss and the Run

Game state at the end of this chapter: a run that can be won. Floor 3
is the last one — no stairs, and the deepest room is a throne room
where the Warden (a very big demon) keeps the crown. The seals slam
shut behind you, the fight gets a health bar, the Warden enrages at
half health and calls imps, and its death drops the Chapter 1
programmer-art crown as a real pickup. Touching it ends the run in a
fifth game phase, `.Victory`, which the compiler demanded arms for
across the whole program. Enemy stats moved to a bestiary file and
now scale per floor.

Build and run:

    ./build.sh && ./crypt

Tests:

    odin test tests

## Changes from ch15

| File | Status | Notes |
|------|--------|-------|
| `src/bestiary.odin` | new | enemy stats table (moved out of main, animation names spelled out — constant strings need no owner), `scaled` per-floor difficulty, the `WARDEN`, the `IMP` |
| `tests/tboss.odin` | new | scaling curve, phase flip, minion cadence, final-floor shape, relock round trip, inside_room |
| `src/ecs.odin` | changed | + `.Boss`, `Boss` (phase, minion timer), `.Crown` pickup; dump knows the boss |
| `src/systems.odin` | changed | + `boss_system` (enrage at half hp, minion calls on a cadence), `find_boss` |
| `src/dungeon.odin` | changed | `generate` takes `final` (no stairs on the last floor); `unlock` remembers the doors so `relock` can slam them; `inside_room` |
| `src/hud.odin` | changed | + `draw_boss_bar` |
| `src/audio.odin` | changed | + `.Roar` (enrage), `.Victory` (C-E-G jingle) |
| `src/loot.odin` | changed | crown label; `apply_pickup` treats the crown like coins/keys (the run's business) |
| `src/main.odin` | changed | `.Victory` phase, boss wiring (lock-in, roar, minion cap by throne-room census, death ceremony), crown drawn with the Chapter 1 primitives, victory screen, `counted` plurals |
| everything else | unchanged | |
