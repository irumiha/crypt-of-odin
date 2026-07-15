// Chapter 6: the crypt gets a shape. The world is a tilemap parsed
// from the ASCII art below, bigger than the window, and a camera
// follows the knight through it. Nobody collides with anything yet;
// the knight is a ghost in his own crypt until Chapter 7.

package crypt

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
BACKGROUND_COLOR :: rl.Color{24, 20, 37, 255}
ATLAS_DIR :: "assets/0x72_DungeonTilesetII_v1.7/"
PLAYER_SPEED :: 170 // px/s; the crypt is large and life is short

// The crypt, drawn in the finest of level editors. Three rooms:
// the entrance hall (top left), the great hall (right), and a
// small vault (bottom), joined by corridors.
CRYPT_MAP :: `
################
#..............#
#..............#   ##########################
#..............#   #........................#
#..............#   #........................#
#..............#####........................#
#...........................................#
#...........................................#
#..............#####........................#
#..............#   #........................#
#..............#   #........................#
#..............#   #........................#
#..............#   #........................#
#########..#####   #........................#
        #..#       #........................#
        #..#       #........................#
     ####..####    #........................#
     #........#    #........................#
     #........#    #........................#
     #........#    #........................#
     #........#    #........................#
     #........#    #........................#
     #........#    ##########################
     #........#
     ##########`

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

spawn_critter :: proc(w: ^World, atlas: ^Atlas, m: Tilemap) {
	// A random monster on a random floor tile, drifting in a random
	// direction, with idle/run animations wired up.
	e := spawn(w, {.Position, .Velocity, .Sprite, .Actor})
	kind := CRITTERS[rand.int_max(len(CRITTERS))]
	w.sprites[e.idx] = make_anim_sprite(atlas, kind.idle_anim, SCALE)
	w.actors[e.idx] = {idle_anim = kind.idle_anim,
	                   run_anim  = kind.run_anim}
	w.positions[e.idx] = random_floor_pos(m)
	w.velocities[e.idx] = {rand.float32_range(-75, 75),
	                       rand.float32_range(-60, 60)}
}

spawn_coin :: proc(w: ^World, atlas: ^Atlas, m: Tilemap) {
	// A coin that expires on its own, somewhere on the floor.
	e := spawn(w, {.Position, .Sprite, .Lifetime})
	w.sprites[e.idx] = make_anim_sprite(atlas, "coin_anim", SCALE)
	w.positions[e.idx] = random_floor_pos(m)
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

	m := parse_map(&atlas, CRYPT_MAP)
	defer destroy_tilemap(&m)

	world := make_world()
	defer destroy_world(&world)

	// The knight starts in the entrance hall.
	knight := spawn(&world, {.Position, .Velocity, .Sprite,
	                         .Actor, .Player})
	world.sprites[knight.idx] = make_anim_sprite(&atlas,
	                                             "knight_m_idle_anim", SCALE)
	world.positions[knight.idx] = {7 * TILE_SIZE, 6 * TILE_SIZE}
	world.actors[knight.idx] = {idle_anim = "knight_m_idle_anim",
	                            run_anim  = "knight_m_run_anim"}

	for _ in 0 ..< 10 {
		spawn_critter(&world, &atlas, m)
	}

	cam := make_camera({SCREEN_WIDTH, SCREEN_HEIGHT})
	cam.target = world.positions[knight.idx] // start on the knight, no glide

	coin_timer: f32

	for !rl.WindowShouldClose() {
		// --- Update ---
		dt := rl.GetFrameTime()
		coin_timer -= dt
		if coin_timer <= 0 {
			coin_timer = 0.5
			spawn_coin(&world, &atlas, m)
		}
		player_input_system(&world, PLAYER_SPEED)
		movement_system(&world, dt)
		bounce_system(&world, pixel_size(m))
		actor_anim_system(&world, &atlas)
		animation_system(&world, dt)
		lifetime_system(&world, dt)

		// The camera watches the knight's center, clamped to the map,
		// zoomed to compensate for display scaling.
		adapt_to_dpi(&cam, {SCREEN_WIDTH, SCREEN_HEIGHT})
		knight_center := world.positions[knight.idx] + rl.Vector2{
			sprite_width(world.sprites[knight.idx]) / 2,
			sprite_height(world.sprites[knight.idx]) / 2,
		}
		camera_follow(&cam, knight_center, pixel_size(m), dt)

		// --- Draw ---
		rl.BeginDrawing()
		rl.ClearBackground(BACKGROUND_COLOR)
		rl.BeginMode2D(cam) // world space: shifted by the camera
		tilemap_draw(m, &atlas)
		draw_system(&world, &atlas)
		rl.EndMode2D() // back to screen space for the HUD
		rl.DrawText(fmt.ctprintf("entities: %d", entity_count(&world)),
		            10, 40, 20, rl.LIGHTGRAY)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()

		// Everything on the temp allocator — query results, tprintf
		// names — lives exactly one frame. One sweep returns it all.
		free_all(context.temp_allocator)
	}
}
