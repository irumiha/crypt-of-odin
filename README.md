# Crypt of Odin

Chapter-by-chapter companion code for the book. Each `code/chNN/`
directory is the complete game as it stands at the end of that
chapter: build it, run it, diff it against its neighbors.

## Requirements

- [Odin](https://odin-lang.org) nightly `dev-2026-07` or later
  (`odin` on your PATH). raylib ships with Odin as `vendor:raylib`;
  there is nothing else to install.

## Building a chapter

    cd code/ch01
    ./build.sh        # odin build src -out:crypt
    ./crypt

Run from the chapter directory.

## Layout

- `code/chNN/src/` — the game (package `crypt`)
- `code/chNN/src/art.odin` — sprite sheets: typed-in pixel-art string grids,
  parsed and rendered at load time (no PNG pack required)
- from ch08: `code/chNN/tests/` — headless tests (`odin test tests`)
- from ch15: `code/chNN/shaders/`
- ch17 adds the web build (`build_web.sh`)
