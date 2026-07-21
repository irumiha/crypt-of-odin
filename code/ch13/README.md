# Chapter 13 — States and Sound

Game state at the end of this chapter: a real game loop around the
game. Title screen (the Chapter 1 ring, back home), pause on Esc, and
a game-over screen with the run's stats — death finally means
something, and restarting constructs a fresh `Run` value. Every sound
is synthesized from arithmetic at startup: nine effects and an
eight-bar A-minor theme, no audio files anywhere.

Build and run:

    ./build.sh && ./crypt

Tests:

    odin test tests

## Changes from ch12

| File | Status | Notes |
|------|--------|-------|
| `src/audio.odin` | new | the synthesizer: `tone` (shape/slide/envelope), `mix`, hand-built WAV headers, sfx bank, streamed music loop; `destroy_audio_bank` |
| `tests/taudio.odin` | new | synth invariants: length, envelope, determinism, saturating mix, WAV header |
| `src/main.odin` | changed | `Game_Phase` state machine (menu/playing/paused/game over), `Run` struct (restart = new value, plus `destroy_run` — the one cleanup Nim's GC hid), sfx wiring, `SetExitKey` so Esc pauses instead of quitting; `Enemy_Stats.scale` (2 for the ogre) |
| `src/input.odin` | changed | `.Pause` action (Esc, P) |
| `src/tilemap.odin` | changed | floor variants `FLOOR_VARIANTS :: 4` (was 8, matching the typed atlas's 4 floor strips) |
| `src/resources.odin` | changed | atlas built from `art.odin` (`build_atlas`) instead of loaded from a PNG pack + index file |
| everything else | unchanged | |
