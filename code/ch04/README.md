# Chapter 4 — An ECS in an Afternoon

Game state at the end of this chapter: ten critters bounce around the
crypt, coins spawn and expire (watch the entity counter plateau as the
free list recycles slots), and the knight stands still because no
system has any business with him.

Build and run:

    ./build.sh && ./crypt

## Changes from ch03

| File | Status | Notes |
|------|--------|-------|
| `src/ecs.odin` | new | the whole ECS: generational `Entity` handles, component columns in a `World`, bit_set-mask queries (temp-allocator slices), `dump`; `make_world`/`destroy_world` |
| `src/systems.odin` | new | movement, bounce, animation, lifetime, draw — each with a `Reads:`/`Writes:` declaration |
| `src/sprites.odin` | changed | scale moved into `Anim_Sprite`; `sprite_width`/`sprite_height` accessors added |
| `src/main.odin` | changed | spawn procs (critters, coins), knight becomes an entity, frame loop becomes a list of system calls; per-frame `free_all(context.temp_allocator)` |
| `src/resources.odin` | unchanged | |
| `assets/` | unchanged | |
