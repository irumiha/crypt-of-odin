# Chapter 17 — Shipping It

Game state at the end of this chapter: the same game, portable. One
structural change makes the web build possible (the frame is a proc,
the game's state is a `Game` struct, because in a browser the event
loop owns the program), and the rest is packaging: a build script that
compiles the whole game to a ~900 KB WebAssembly bundle.

Desktop build and run:

    ./build_desktop.sh && ./crypt

Tests:

    odin test tests

Web build (with the [emsdk](https://emscripten.org) installed at
`~/Tools/emsdk`, or edit the path in the script):

    ./build_web.sh
    python3 -m http.server -d build/web    # serve it, don't file:// it

Autostart (for smoke tests and screenshots — the menu presses SPACE
by itself after a second):

    ./build_desktop.sh -define:AUTOSTART=true

## Changes from ch16

| File | Status | Notes |
|------|--------|-------|
| `src/game.odin` | new (was `main.odin`) | the whole game behind four procs: `game_init` / `game_update` (one frame) / `game_should_run` / `game_shutdown`, state in one `Game` struct — in a browser, emscripten owns the loop and calls the frame; on desktop, a plain `for` does |
| `src/main_desktop/` | new | the desktop entry point: `set_working_directory` to the executable's dir, then the classic loop |
| `src/main_web/` | new | the wasm entry points (`main_start`/`main_update` exported to the page), emscripten's allocator and logger wired into Odin's context (adapted from karl-zylinski/odin-raylib-web, MIT), and the HTML shell |
| `build_desktop.sh`, `build_web.sh` | new (replace `build.sh`) | the web script links the raylib wasm library that ships inside Odin; no `ALLOW_MEMORY_GROWTH` — a growable heap is a resizable ArrayBuffer, and Chrome rejects views of those in `texImage2D`; fixed 64 MB instead |
| `src/shaders.odin` | unchanged | the GLSL 100 dialect and the compile-time switch have been waiting since Chapter 15 |
| GitHub workflows | deferred | the Nim book shipped release/pages workflows here; the Odin equivalents are pending the prose pass |
| everything else | unchanged | |
