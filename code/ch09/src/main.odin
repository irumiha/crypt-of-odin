// Chapter 9: the crypt fights back. Critters became enemies with
// health, chase AI, and contact damage; the knight got hit points,
// i-frames, knockback, and a sword (Space or J). The sword is not a
// special case anywhere: it is an entity with a collider, a damage
// component, and 0.15 seconds to live.

package crypt

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
BACKGROUND_COLOR :: rl.Color{24, 20, 37, 255}
PLAYER_SPEED :: 170 // px/s; the crypt is large and life is short
ATTACK_COOLDOWN_TIME :: 0.35

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

Enemy_Stats :: struct {
	// An archetype is data: which art, how tough, how fast, how far
	// it can smell you.
	idle_anim: string,
	run_anim:  string,
	hp:        i32,
	speed:     f32,
	aggro:     f32,
	scale:     f32, // multiplies SCALE at spawn; 2 for the ogre
}

// Every animation here must exist in the atlas; a bad name fails
// loudly at spawn. The names are spelled out instead of built from a
// base name at spawn time: strings built at runtime need an owner;
// strings in a constant table need nobody.
@(rodata)
ENEMY_KINDS := [?]Enemy_Stats{
	{"goblin_idle_anim", "goblin_run_anim", 2, 85, 150, 1},
	{"skelet_idle_anim", "skelet_run_anim", 2, 70, 170, 1},
	{"imp_idle_anim", "imp_run_anim", 1, 95, 140, 1},
	{"chort_idle_anim", "chort_run_anim", 3, 80, 160, 1},
	{"ogre_idle_anim", "ogre_run_anim", 5, 45, 190, 2},
}

spawn_enemy :: proc(w: ^World, atlas: ^Atlas, m: Tilemap) -> Entity {
	// One archetype from the table, assembled as a component bundle.
	// Returns the entity so debug mode can reposition it.
	stats := ENEMY_KINDS[rand.int_max(len(ENEMY_KINDS))]
	e := spawn(w, {.Position, .Velocity, .Sprite, .Actor,
	               .Collider, .Bounce, .Health, .Ai,
	               .Contact_Damage})
	w.sprites[e.idx] = make_anim_sprite(atlas, stats.idle_anim, SCALE * stats.scale)
	w.actors[e.idx] = {idle_anim = stats.idle_anim,
	                   run_anim  = stats.run_anim}
	w.colliders[e.idx] = feet_collider(w.sprites[e.idx], .Enemy,
	                                   hits = {.Player})
	w.healths[e.idx] = {hp = stats.hp, max_hp = stats.hp,
	                    invuln_time = 0.3}
	w.ais[e.idx] = {chase_speed = stats.speed, aggro = stats.aggro}
	w.contact_damages[e.idx] = {amount = 1, knockback = 250}
	w.positions[e.idx] = random_floor_pos(m)
	w.velocities[e.idx] = {rand.float32_range(-60, 60),
	                       rand.float32_range(-60, 60)}
	return e
}

swing_sword :: proc(w: ^World, atlas: ^Atlas, player: Entity) {
	// The sword: an entity with a sprite, a hitbox slightly bigger than
	// the blade, one point of damage, and 0.15 seconds to live. It
	// appears on whichever side the knight is facing.
	facing_left := w.sprites[player.idx].flip_x
	e := spawn(w, {.Position, .Sprite, .Collider, .Lifetime,
	               .Contact_Damage})
	w.sprites[e.idx] = make_static_sprite(atlas, "weapon_knight_sword",
	                                      SCALE)
	w.sprites[e.idx].flip_x = facing_left
	px := w.positions[player.idx]
	x := px.x + sprite_width(w.sprites[player.idx])
	if facing_left {
		x = px.x - sprite_width(w.sprites[e.idx])
	}
	w.positions[e.idx] = {x, px.y + 6}
	w.colliders[e.idx] = {
		offset = {-6, -6},
		size   = {sprite_width(w.sprites[e.idx]) + 12,
		          sprite_height(w.sprites[e.idx]) + 12},
		layer  = .Player_Attack, hits = {.Enemy},
	}
	w.contact_damages[e.idx] = {amount = 1, knockback = 300}
	w.lifetimes[e.idx] = 0.15
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
	knight_start := rl.Vector2{7 * TILE_SIZE, 6 * TILE_SIZE}
	knight := spawn(&world, {.Position, .Velocity, .Sprite, .Actor,
	                         .Player, .Collider, .Health})
	world.sprites[knight.idx] = make_anim_sprite(&atlas,
	                                             "knight_m_idle_anim", SCALE)
	world.positions[knight.idx] = knight_start
	world.actors[knight.idx] = {idle_anim = "knight_m_idle_anim",
	                            run_anim  = "knight_m_run_anim"}
	world.colliders[knight.idx] = feet_collider(
		world.sprites[knight.idx], .Player, hits = {.Pickup})
	world.healths[knight.idx] = {hp = 6, max_hp = 6, invuln_time = 0.8}

	for _ in 0 ..< 10 {
		spawn_enemy(&world, &atlas, m)
	}

	fmt.println(dump(&world, knight)) // the print test: any entity, reassembled

	cam := make_camera({SCREEN_WIDTH, SCREEN_HEIGHT})
	cam.target = world.positions[knight.idx] // start on the knight, no glide

	coin_timer: f32
	coins_collected := 0
	kills := 0
	attack_cooldown: f32
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
				e := spawn_enemy(&world, &atlas, m)
				world.positions[e.idx] = mouse_world(cam)
			}
		}
		coin_timer -= dt
		if coin_timer <= 0 {
			coin_timer = 0.5
			spawn_coin(&world, &atlas, m)
		}
		attack_cooldown -= dt
		if was_pressed(.Attack) && attack_cooldown <= 0 {
			attack_cooldown = ATTACK_COOLDOWN_TIME
			swing_sword(&world, &atlas, knight)
		}
		player_input_system(&world, PLAYER_SPEED)
		ai_system(&world, knight)
		health_system(&world, dt)
		movement_system(&world, m, dt, dbg.noclip)
		contact_system(&world)
		coins_collected += pickup_system(&world)
		damage_system(&world)
		for spot in death_system(&world) {
			kills += 1
			d := spawn(&world, {.Position, .Sprite, .Lifetime})
			world.sprites[d.idx] = make_static_sprite(&atlas, "skull", SCALE)
			world.positions[d.idx] = spot
			world.lifetimes[d.idx] = 4
		}
		if world.healths[knight.idx].hp <= 0 {
			// Death proper arrives with the state machine in Chapter 13;
			// for now the crypt is merciful and sends him back to the
			// entrance.
			world.healths[knight.idx].hp = world.healths[knight.idx].max_hp
			world.healths[knight.idx].invuln = 1.5
			world.positions[knight.idx] = knight_start
		}
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
		hp := world.healths[knight.idx]
		rl.DrawText(fmt.ctprintf("hp: %d/%d", hp.hp, hp.max_hp),
		            10, 40, 20, rl.RED)
		rl.DrawText(fmt.ctprintf("coins: %d", coins_collected),
		            10, 70, 20, rl.GOLD)
		rl.DrawText(fmt.ctprintf("kills: %d", kills),
		            10, 100, 20, rl.LIGHTGRAY)
		debug_draw_panel(dbg, &world, cam)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()

		// Everything on the temp allocator — query results, tprintf
		// names — lives exactly one frame. One sweep returns it all.
		free_all(context.temp_allocator)
	}
}
