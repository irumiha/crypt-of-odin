# Chapter 2 — Odin for People Who Write Java for Money

Game state at the end of this chapter: the Chapter 1 title scene with
a field of golden embers rising behind the crown.

Build and run:

    ./build.sh && ./crypt

The language tour (pure Odin, no raylib):

    odin run tour.odin -file

## Changes from ch01

| File | Status | Notes |
|------|--------|-------|
| `src/embers.odin` | new | `Ember` value struct; spawn/update/draw; swap-and-shrink removal |
| `src/main.odin` | changed | ember storage + spawn timer in the loop |
| `tour.odin` | new | every language snippet in the chapter, runnable |
