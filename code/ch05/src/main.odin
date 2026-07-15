// Chapter 5: the knight walks. An action map turns held keys into a
// movement vector, a player-tagged entity picks it up as velocity, and
// an actor system switches everyone between idle and run animations
// and faces them where they're going — critters included.

package crypt

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
SCALE :: 2 // 16px art, 32px on screen
TILE_SIZE :: 16 * SCALE
BACKGROUND_COLOR :: rl.Color{24, 20, 37, 255}
ATLAS_DIR :: "assets/0x72_DungeonTilesetII_v1.7/"
PLAYER_SPEED :: 170 // px/s; the crypt is large and life is short

Critter :: struct {
	idle_anim: string,
	run_anim:  string,
}

// Every animation here must exist in the atlas; a bad name fails
// loudly at spawn. The names are spelled out instead of built from a
// base name at spawn time: strings built at runtime need an owner;
// strings in a constant table need nobody.
@(rodata)
CRITTERS := [?]Critter{
	{"goblin_idle_anim", "goblin_run_anim"},
	{"skelet_idle_anim", "skelet_run_anim"},
	{"imp_idle_anim", "imp_run_anim"},
	{"chort_idle_anim", "chort_run_anim"},
	{"ogre_idle_anim", "ogre_run_anim"},
}

spawn_critter :: proc(w: ^World, atlas: ^Atlas) {
	// A random monster somewhere on the floor, drifting in a random
	// direction, with idle/run animations wired up.
	e := spawn(w, {.Position, .Velocity, .Sprite, .Actor})
	kind := CRITTERS[rand.int_max(len(CRITTERS))]
	w.sprites[e.idx] = make_anim_sprite(atlas, kind.idle_anim, SCALE)
	w.actors[e.idx] = {idle_anim = kind.idle_anim,
	                   run_anim  = kind.run_anim}
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

	atlas := load_atlas(ATLAS_DIR + "0x72_DungeonTilesetII_v1.7.png",
	                    ATLAS_DIR + "tile_list_v1.7")
	defer destroy_atlas(&atlas)

	// The floor: one variant per cell, rolled once at startup (Chapter 3).
	COLS :: SCREEN_WIDTH / TILE_SIZE
	ROWS :: SCREEN_HEIGHT / TILE_SIZE + 1
	floor_tiles: [dynamic]rl.Rectangle
	defer delete(floor_tiles)
	for _ in 0 ..< COLS * ROWS {
		name := "floor_1"
		if rand.float32() >= 0.9 {
			name = fmt.tprintf("floor_%d", 2 + rand.int_max(7))
		}
		append(&floor_tiles, atlas_rect(&atlas, name))
	}

	world := make_world()
	defer destroy_world(&world)

	// The knight is now a player: the tag routes input to him, the
	// Velocity lets movement carry him, the Actor swaps his animations.
	knight := spawn(&world, {.Position, .Velocity, .Sprite,
	                         .Actor, .Player})
	world.sprites[knight.idx] = make_anim_sprite(&atlas,
	                                             "knight_m_idle_anim", SCALE)
	world.positions[knight.idx] = {(SCREEN_WIDTH - 16 * SCALE) / 2,
	                               (SCREEN_HEIGHT - 28 * SCALE) / 2}
	world.actors[knight.idx] = {idle_anim = "knight_m_idle_anim",
	                            run_anim  = "knight_m_run_anim"}

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
		player_input_system(&world, PLAYER_SPEED)
		movement_system(&world, dt)
		bounce_system(&world, {SCREEN_WIDTH, SCREEN_HEIGHT})
		actor_anim_system(&world, &atlas)
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
		rl.DrawText(fmt.ctprintf("entities: %d", entity_count(&world)),
		            10, 40, 20, rl.LIGHTGRAY)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()

		// Everything on the temp allocator — query results, tprintf
		// names — lives exactly one frame. One sweep returns it all.
		free_all(context.temp_allocator)
	}
}
