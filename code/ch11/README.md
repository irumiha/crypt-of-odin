# Chapter 11 — Loot, Items, and Pickups

Game state at the end of this chapter: the coin faucet is gone; loot
falls from dead enemies via a weighted drop table. Coins count, hearts
heal (never past max), the blue flask permanently raises max hp, and
the green flask sharpens the sword. Drops expire after a while, and
balancing the whole economy means editing one table.

Build and run:

    ./build.sh && ./crypt

Tests:

    odin test tests

## Changes from ch10

| File | Status | Notes |
|------|--------|-------|
| `src/loot.odin` | new | `Drop_Table`/`Drop_Entry`, cumulative-weight `roll` (explicit `rand.Generator`; comma-ok plays Nim's `Option`), `apply_pickup` effects, the `ENEMY_DROPS` table |
| `tests/tloot.odin` | new | drop distribution (shape, not decimals), same-dice determinism, heal clamp, flask effects |
| `src/ecs.odin` | changed | `Pickup_Kind` grew `.Heart`, `.Max_Hp`, `.Power` |
| `src/main.odin` | changed | `spawn_coin` faucet removed; `spawn_loot` per kind; death rolls the table (its own dice, seeded off the run seed); `swing_sword` takes a damage stat; `power` on the HUD |
| everything else | unchanged | |
