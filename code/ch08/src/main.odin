// Chapter 8: the game grows instruments. F1 opens debug mode: collider
// boxes, an entity inspector on the cursor, noclip, teleport, spawn,
// and time scaling. The same chapter gives the world headless unit
// tests (see tests/); this file only gained the debug wiring.

package crypt

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
BACKGROUND_COLOR :: rl.Color{24, 20, 37, 255}
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

spawn_critter :: proc(w: ^World, atlas: ^Atlas, m: Tilemap) -> Entity {
	// A random monster on a random floor tile, bouncing off walls.
	// Returns the entity so debug mode can reposition it.
	e := spawn(w, {.Position, .Velocity, .Sprite, .Actor,
	               .Collider, .Bounce})
	kind := CRITTERS[rand.int_max(len(CRITTERS))]
	w.sprites[e.idx] = make_anim_sprite(atlas, kind.idle_anim, SCALE)
	w.actors[e.idx] = {idle_anim = kind.idle_anim,
	                   run_anim  = kind.run_anim}
	w.positions[e.idx] = random_floor_pos(m)
	w.velocities[e.idx] = {rand.float32_range(-75, 75),
	                       rand.float32_range(-60, 60)}
	w.colliders[e.idx] = feet_collider(w.sprites[e.idx], .Enemy)
	return e
}

spawn_coin :: proc(w: ^World, atlas: ^Atlas, m: Tilemap) {
	// A coin that expires on its own unless somebody picks it up first.
	e := spawn(w, {.Position, .Sprite, .Lifetime, .Collider})
	w.sprites[e.idx] = make_anim_sprite(atlas, "coin_anim", SCALE)
	w.positions[e.idx] = random_floor_pos(m)
	// Coins use their whole box: they're small and meant to be touched.
	w.colliders[e.idx] = {size = {sprite_width(w.sprites[e.idx]),
	                              sprite_height(w.sprites[e.idx])},
	                      layer = .Pickup}
	w.lifetimes[e.idx] = rand.float32_range(2, 6)
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_HIGHDPI})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Crypt of Odin")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	atlas := build_atlas(ART)
	defer destroy_atlas(&atlas)

	m := parse_map(CRYPT_MAP)
	defer destroy_tilemap(&m)
	skin := make_skin(&atlas)

	world := make_world()
	defer destroy_world(&world)

	// The knight: his hits set is what makes coins collectable.
	knight := spawn(&world, {.Position, .Velocity, .Sprite,
	                         .Actor, .Player, .Collider})
	world.sprites[knight.idx] = make_anim_sprite(&atlas,
	                                             "knight_m_idle_anim", SCALE)
	world.positions[knight.idx] = {7 * TILE_SIZE, 6 * TILE_SIZE}
	world.actors[knight.idx] = {idle_anim = "knight_m_idle_anim",
	                            run_anim  = "knight_m_run_anim"}
	world.colliders[knight.idx] = feet_collider(
		world.sprites[knight.idx], .Player, hits = {.Pickup})

	for _ in 0 ..< 10 {
		spawn_critter(&world, &atlas, m)
	}

	fmt.println(dump(&world, knight)) // the print test: any entity, reassembled

	cam := make_camera({SCREEN_WIDTH, SCREEN_HEIGHT})
	cam.target = world.positions[knight.idx] // start on the knight, no glide

	coin_timer: f32
	coins_collected := 0
	dbg := init_debug()

	for !rl.WindowShouldClose() {
		// --- Update ---
		debug_update(&dbg)
		dt := rl.GetFrameTime() * dbg.time_scale
		if dbg.enabled { // god keys that need main's context
			if rl.IsKeyPressed(.T) {
				world.positions[knight.idx] = mouse_world(cam)
			}
			if rl.IsKeyPressed(.E) {
				e := spawn_critter(&world, &atlas, m)
				world.positions[e.idx] = mouse_world(cam)
			}
		}
		coin_timer -= dt
		if coin_timer <= 0 {
			coin_timer = 0.5
			spawn_coin(&world, &atlas, m)
		}
		player_input_system(&world, PLAYER_SPEED)
		movement_system(&world, m, dt, dbg.noclip)
		contact_system(&world)
		coins_collected += pickup_system(&world)
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
		tilemap_draw(m, &atlas, skin)
		draw_system(&world, &atlas)
		debug_draw_world(dbg, &world) // collider boxes, when enabled
		rl.EndMode2D() // back to screen space for the HUD
		rl.DrawText(fmt.ctprintf("coins: %d", coins_collected),
		            10, 40, 20, rl.GOLD)
		rl.DrawText(fmt.ctprintf("entities: %d", entity_count(&world)),
		            10, 70, 20, rl.LIGHTGRAY)
		debug_draw_panel(dbg, &world, cam)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()

		// Everything on the temp allocator — query results, tprintf
		// names — lives exactly one frame. One sweep returns it all.
		free_all(context.temp_allocator)
	}
}
