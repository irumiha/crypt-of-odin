// Chapter 4: the crypt comes alive. Critters bounce around the floor,
// coins spawn and expire, and the knight stands still because no
// system has any business with him (he has no Velocity component).
// The frame loop is now just a list of system calls.

package crypt

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
SCALE :: 2 // 16px art, 32px on screen
TILE_SIZE :: 16 * SCALE
BACKGROUND_COLOR :: rl.Color{24, 20, 37, 255}
// Every name here must exist in the atlas as <name>_idle_anim; a bad
// one fails loudly at spawn ("ice_zombie" taught us that; the pack
// names its animation ice_zombie_anim, with no idle variant).
// @(rodata) because a `::` constant has no address to index at runtime.
@(rodata)
CRITTER_NAMES := [?]string{"goblin", "skelet", "imp", "chort", "ogre"}

spawn_critter :: proc(w: ^World, atlas: ^Atlas) {
	// A random monster somewhere on the floor, drifting in a random
	// direction. Spawning is: claim a slot with a mask, fill in the
	// columns you declared.
	e := spawn(w, {.Position, .Velocity, .Sprite})
	name := CRITTER_NAMES[rand.int_max(len(CRITTER_NAMES))]
	w.sprites[e.idx] = make_anim_sprite(atlas,
	                                    fmt.tprintf("%s_idle_anim", name),
	                                    SCALE)
	w.positions[e.idx] = {
		rand.float32_range(TILE_SIZE, SCREEN_WIDTH - 2 * TILE_SIZE),
		rand.float32_range(TILE_SIZE, SCREEN_HEIGHT - 2 * TILE_SIZE),
	}
	w.velocities[e.idx] = {rand.float32_range(-75, 75),
	                       rand.float32_range(-60, 60)}
}

spawn_coin :: proc(w: ^World, atlas: ^Atlas) {
	// A coin that expires on its own: same spawn shape as a critter,
	// but with Lifetime instead of Velocity in the parts list.
	e := spawn(w, {.Position, .Sprite, .Lifetime})
	w.sprites[e.idx] = make_anim_sprite(atlas, "coin_anim", SCALE)
	w.positions[e.idx] = {
		rand.float32_range(TILE_SIZE, SCREEN_WIDTH - 2 * TILE_SIZE),
		rand.float32_range(TILE_SIZE, SCREEN_HEIGHT - 2 * TILE_SIZE),
	}
	w.lifetimes[e.idx] = rand.float32_range(1, 4)
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_HIGHDPI})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Crypt of Odin")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	atlas := build_atlas(ART)
	defer destroy_atlas(&atlas)

	// The floor: one variant per cell, rolled once at startup (Chapter 3).
	COLS :: SCREEN_WIDTH / TILE_SIZE
	ROWS :: SCREEN_HEIGHT / TILE_SIZE + 1
	floor_tiles: [dynamic]rl.Rectangle
	defer delete(floor_tiles)
	for _ in 0 ..< COLS * ROWS {
		name := "floor_1"
		if rand.float32() >= 0.9 {
			name = fmt.tprintf("floor_%d", 2 + rand.int_max(3))
		}
		append(&floor_tiles, atlas_rect(&atlas, name))
	}

	world := make_world()
	defer destroy_world(&world)

	// The knight: no Velocity, so movement and bounce never touch him.
	// Behavior comes from the parts list, not from an is_player flag.
	knight := spawn(&world, {.Position, .Sprite})
	world.sprites[knight.idx] = make_anim_sprite(&atlas,
	                                             "knight_m_idle_anim", SCALE)
	world.positions[knight.idx] = {(SCREEN_WIDTH - 16 * SCALE) / 2,
	                               (SCREEN_HEIGHT - 16 * SCALE) / 2}

	for _ in 0 ..< 10 {
		spawn_critter(&world, &atlas)
	}

	fmt.println(dump(&world, knight)) // the print test: any entity, reassembled

	coin_timer: f32

	for !rl.WindowShouldClose() {
		// --- Update ---
		dt := rl.GetFrameTime()
		coin_timer -= dt
		if coin_timer <= 0 {
			coin_timer = 0.5
			spawn_coin(&world, &atlas)
		}
		movement_system(&world, dt)
		bounce_system(&world, {SCREEN_WIDTH, SCREEN_HEIGHT})
		animation_system(&world, dt)
		lifetime_system(&world, dt)

		// --- Draw ---
		rl.BeginDrawing()
		rl.ClearBackground(BACKGROUND_COLOR)
		for rect, i in floor_tiles {
			col := i % COLS
			row := i / COLS
			dest := rl.Rectangle{f32(col * TILE_SIZE), f32(row * TILE_SIZE),
			                     TILE_SIZE, TILE_SIZE}
			rl.DrawTexturePro(atlas.texture, rect, dest, {0, 0}, 0, rl.WHITE)
		}
		draw_system(&world, &atlas)
		// Watch this plateau: expired coins hand their slots to new ones.
		rl.DrawText(fmt.ctprintf("entities: %d", entity_count(&world)),
		            10, 40, 20, rl.LIGHTGRAY)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()

		// Everything on the temp allocator — query results, tprintf
		// names — lives exactly one frame. One sweep returns it all.
		free_all(context.temp_allocator)
	}
}
