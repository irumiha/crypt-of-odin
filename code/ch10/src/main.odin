// Chapter 10: the crypt generates itself. Every floor is an
// Isaac-style grid of screen-sized rooms built from a seed, the
// camera locks to the current room and pans on transitions, the
// stairs down hide behind gold-sealed doors, and a flask of solvent
// (nobody drew a key sprite; improvise) dissolves them. Stairs
// descend to a fresh, slightly meaner floor.

package crypt

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
BACKGROUND_COLOR :: rl.Color{24, 20, 37, 255}
PLAYER_SPEED :: 170
ATTACK_COOLDOWN_TIME :: 0.35

Enemy_Stats :: struct {
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

spawn_enemy :: proc(w: ^World, atlas: ^Atlas, pos: rl.Vector2) -> Entity {
	// One archetype from the table, assembled as a component bundle.
	// Returns the entity so debug mode can reposition it.
	stats := ENEMY_KINDS[rand.int_max(len(ENEMY_KINDS))]
	e := spawn(w, {.Position, .Velocity, .Sprite, .Actor,
	               .Collider, .Bounce, .Health, .Ai,
	               .Contact_Damage})
	w.sprites[e.idx] = make_anim_sprite(atlas, stats.idle_anim,
	                                    SCALE * stats.scale)
	w.actors[e.idx] = {idle_anim = stats.idle_anim,
	                   run_anim  = stats.run_anim}
	w.colliders[e.idx] = feet_collider(w.sprites[e.idx], .Enemy,
	                                   hits = {.Player})
	w.healths[e.idx] = {hp = stats.hp, max_hp = stats.hp,
	                    invuln_time = 0.3}
	w.ais[e.idx] = {chase_speed = stats.speed, aggro = stats.aggro}
	w.contact_damages[e.idx] = {amount = 1, knockback = 250}
	w.positions[e.idx] = pos
	w.velocities[e.idx] = {rand.float32_range(-60, 60),
	                       rand.float32_range(-60, 60)}
	return e
}

spawn_coin :: proc(w: ^World, atlas: ^Atlas, m: Tilemap) {
	// A coin that expires on its own unless somebody picks it up first.
	e := spawn(w, {.Position, .Sprite, .Lifetime, .Collider, .Pickup})
	w.sprites[e.idx] = make_anim_sprite(atlas, "coin_anim", SCALE)
	w.positions[e.idx] = random_floor_pos(m)
	w.colliders[e.idx] = {size = {sprite_width(w.sprites[e.idx]),
	                              sprite_height(w.sprites[e.idx])},
	                      layer = .Pickup}
	w.pickup_kinds[e.idx] = .Coin
	w.lifetimes[e.idx] = rand.float32_range(2, 6)
}

spawn_key :: proc(w: ^World, atlas: ^Atlas, pos: rl.Vector2) {
	// The seal-dissolving flask. Persistent: no lifetime, it waits.
	e := spawn(w, {.Position, .Sprite, .Collider, .Pickup})
	w.sprites[e.idx] = make_static_sprite(atlas, "flask_big_yellow", SCALE)
	w.colliders[e.idx] = {size = {sprite_width(w.sprites[e.idx]),
	                              sprite_height(w.sprites[e.idx])},
	                      layer = .Pickup}
	w.pickup_kinds[e.idx] = .Key
	w.positions[e.idx] = pos
}

swing_sword :: proc(w: ^World, atlas: ^Atlas, player: Entity) {
	// The sword: an entity with a sprite, a hitbox slightly bigger than
	// the blade, one point of damage, and 0.15 seconds to live.
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

populate_floor :: proc(w: ^World, d: Dungeon, atlas: ^Atlas,
                       floor_num: int, carry_hp: i32) -> Entity {
	// A fresh World for a fresh floor: the knight (keeping his hp from
	// the stairs), enemies in every room but his, and the key.
	knight := spawn(w, {.Position, .Velocity, .Sprite, .Actor,
	                    .Player, .Collider, .Health})
	w.sprites[knight.idx] = make_anim_sprite(atlas, "knight_m_idle_anim",
	                                         SCALE)
	w.actors[knight.idx] = {idle_anim = "knight_m_idle_anim",
	                        run_anim  = "knight_m_run_anim"}
	w.colliders[knight.idx] = feet_collider(
		w.sprites[knight.idx], .Player, hits = {.Pickup})
	w.healths[knight.idx] = {hp = carry_hp, max_hp = 6, invuln_time = 0.8}
	w.positions[knight.idx] = room_center(d, d.start_room) - {16, 28}

	// Deeper floors pack more enemies into every room.
	per_room := min(2 + floor_num, 6)
	for i in 0 ..< len(d.rooms) {
		if i != d.start_room {
			for _ in 0 ..< per_room {
				spawn_enemy(w, atlas, random_pos_in(d, i))
			}
		}
	}
	spawn_key(w, atlas, random_pos_in(d, d.key_room))
	return knight
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_HIGHDPI})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Crypt of Odin")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	atlas := build_atlas(ART)
	defer destroy_atlas(&atlas)
	skin := make_skin(&atlas)

	// One run seed makes every floor of this run reproducible; print it
	// so a bug report can say "seed 12345, floor 3".
	run_seed := rand.int63_max(1_000_000)
	fmt.println("run seed:", run_seed)

	floor_num := 1
	crypt := generate(run_seed, floor_num)
	defer destroy_dungeon(&crypt)
	world := make_world()
	defer destroy_world(&world)
	knight := populate_floor(&world, crypt, &atlas, floor_num,
	                         carry_hp = 6)

	cam := make_camera({SCREEN_WIDTH, SCREEN_HEIGHT})
	cam.target = room_center(crypt, crypt.start_room)

	coin_timer: f32
	coins_collected := 0
	kills := 0
	attack_cooldown: f32
	dbg := init_debug()

	for !rl.WindowShouldClose() {
		// --- Update ---
		debug_update(&dbg)
		dt := rl.GetFrameTime() * dbg.time_scale
		if dbg.enabled {
			if rl.IsKeyPressed(.T) {
				world.positions[knight.idx] = mouse_world(cam)
			}
			if rl.IsKeyPressed(.E) {
				spawn_enemy(&world, &atlas, mouse_world(cam))
			}
		}
		coin_timer -= dt
		if coin_timer <= 0 {
			coin_timer = 0.5
			spawn_coin(&world, &atlas, crypt.tilemap)
		}
		attack_cooldown -= dt
		if was_pressed(.Attack) && attack_cooldown <= 0 {
			attack_cooldown = ATTACK_COOLDOWN_TIME
			swing_sword(&world, &atlas, knight)
		}
		player_input_system(&world, PLAYER_SPEED)
		ai_system(&world, knight, crypt)
		health_system(&world, dt)
		movement_system(&world, crypt.tilemap, dt, dbg.noclip)
		contact_system(&world)
		damage_system(&world)
		for spot in death_system(&world) {
			kills += 1
			d := spawn(&world, {.Position, .Sprite, .Lifetime})
			world.sprites[d.idx] = make_static_sprite(&atlas, "skull", SCALE)
			world.positions[d.idx] = spot
			world.lifetimes[d.idx] = 4
		}
		if world.healths[knight.idx].hp <= 0 {
			// Death proper arrives with Chapter 13's state machine; for
			// now the crypt is merciful and sends him back to this
			// floor's start.
			world.healths[knight.idx].hp = world.healths[knight.idx].max_hp
			world.healths[knight.idx].invuln = 1.5
			world.positions[knight.idx] = room_center(crypt, crypt.start_room) - {16, 28}
		}
		for kind in pickup_system(&world) {
			switch kind {
			case .Coin: coins_collected += 1
			case .Key:  unlock(&crypt)
			}
		}
		actor_anim_system(&world, &atlas)
		animation_system(&world, dt)
		lifetime_system(&world, dt)

		// Standing on the stairs takes them.
		feet := collider_rect(&world, knight.idx)
		feet_tile := rl.Vector2{feet.x + feet.width / 2,
		                        feet.y + feet.height / 2}
		if tile_at(crypt.tilemap, tile_coord(feet_tile.x),
		           tile_coord(feet_tile.y)) == .Stairs {
			floor_num += 1
			hp := world.healths[knight.idx].hp
			// The old floor's arrays go back by hand: the cleanup is a
			// visible pair of destroys before the rebuild.
			destroy_dungeon(&crypt)
			crypt = generate(run_seed + i64(floor_num) * 7919, floor_num)
			destroy_world(&world)
			world = make_world()
			knight = populate_floor(&world, crypt, &atlas, floor_num,
			                        carry_hp = hp)
			cam.target = room_center(crypt, crypt.start_room)
		}

		// The camera locks to whichever room holds the knight and pans
		// on transitions (Chapter 6's easing, aimed at room centers).
		adapt_to_dpi(&cam, {SCREEN_WIDTH, SCREEN_HEIGHT})
		knight_center := world.positions[knight.idx] + rl.Vector2{
			sprite_width(world.sprites[knight.idx]) / 2,
			sprite_height(world.sprites[knight.idx]) / 2,
		}
		room := room_at(crypt, knight_center)
		cam_target := knight_center // mid-doorway: follow him
		if room >= 0 {
			cam_target = room_center(crypt, room)
		}
		camera_follow(&cam, cam_target, pixel_size(crypt.tilemap), dt,
		              speed = 6)

		// --- Draw ---
		rl.BeginDrawing()
		rl.ClearBackground(BACKGROUND_COLOR)
		rl.BeginMode2D(cam)
		tilemap_draw(crypt.tilemap, &atlas, skin)
		draw_system(&world, &atlas)
		debug_draw_world(dbg, &world)
		rl.EndMode2D()
		hp := world.healths[knight.idx]
		rl.DrawText(fmt.ctprintf("floor: %d", floor_num),
		            10, 40, 20, rl.LIGHTGRAY)
		rl.DrawText(fmt.ctprintf("hp: %d/%d", hp.hp, hp.max_hp),
		            10, 70, 20, rl.RED)
		rl.DrawText(fmt.ctprintf("coins: %d", coins_collected),
		            10, 100, 20, rl.GOLD)
		if is_locked(crypt) {
			rl.DrawText("the stairs are sealed", 10, 130, 20, rl.GOLD)
		} else {
			rl.DrawText("the way down is open", 10, 130, 20, rl.GREEN)
		}
		rl.DrawFPS(10, 10)
		rl.EndDrawing()

		// Everything on the temp allocator — query results, tprintf
		// names — lives exactly one frame. One sweep returns it all.
		free_all(context.temp_allocator)
	}
}
