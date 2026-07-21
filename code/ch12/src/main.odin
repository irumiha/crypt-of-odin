// Chapter 12: the game learns to present itself. Hearts instead of
// an hp string, icon stats, a minimap built from the floor graph,
// and floating damage numbers in world space, driven by the damage
// events the combat system now publishes.

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
	w.sprites[e.idx] = make_anim_sprite(atlas, stats.idle_anim, SCALE * stats.scale)
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

spawn_loot :: proc(w: ^World, atlas: ^Atlas, pos: rl.Vector2,
                   kind: Pickup_Kind) {
	// One dropped item where an enemy fell. Drops expire after a while;
	// the crypt keeps a tidy floor.
	e := spawn(w, {.Position, .Sprite, .Lifetime, .Collider, .Pickup})
	switch kind {
	case .Coin:   w.sprites[e.idx] = make_anim_sprite(atlas, "coin_anim", SCALE)
	case .Heart:  w.sprites[e.idx] = make_static_sprite(atlas, "ui_heart_full", SCALE)
	case .Max_Hp: w.sprites[e.idx] = make_static_sprite(atlas, "flask_big_blue", SCALE)
	case .Power:  w.sprites[e.idx] = make_static_sprite(atlas, "flask_big_green", SCALE)
	case .Key:    w.sprites[e.idx] = make_static_sprite(atlas, "flask_big_yellow", SCALE)
	}
	w.colliders[e.idx] = {size = {sprite_width(w.sprites[e.idx]),
	                              sprite_height(w.sprites[e.idx])},
	                      layer = .Pickup}
	w.pickup_kinds[e.idx] = kind
	w.positions[e.idx] = pos
	w.lifetimes[e.idx] = 12
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

swing_sword :: proc(w: ^World, atlas: ^Atlas, player: Entity,
                    damage: i32) {
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
	w.contact_damages[e.idx] = {amount = damage, knockback = 300}
	w.lifetimes[e.idx] = 0.15
}

spawn_damage_number :: proc(w: ^World, ev: Damage_Event) {
	// A little number that jumps out of whoever got hurt, drifts up,
	// and fades. Pure presentation, so it lives outside the systems.
	e := spawn(w, {.Position, .Velocity, .Lifetime, .Float_Text})
	w.positions[e.idx] = ev.pos
	w.velocities[e.idx] = {0, -30}
	w.lifetimes[e.idx] = 0.7
	w.float_texts[e.idx] = ev.amount
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
	rl.SetConfigFlags({.WINDOW_HIGHDPI, .WINDOW_RESIZABLE})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Crypt of Odin")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	atlas := build_atlas(ART)
	defer destroy_atlas(&atlas)
	skin := make_skin(&atlas)

	// The whole game renders into this fixed logical frame; the window
	// only ever sees its integer-scaled, letterboxed image.
	target := rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
	defer rl.UnloadRenderTexture(target)

	// One run seed makes every floor of this run reproducible; print it
	// so a bug report can say "seed 12345, floor 3".
	run_seed := rand.int63_max(1_000_000)
	fmt.println("run seed:", run_seed)
	// Loot gets its own dice too, so drops never disturb the map seed.
	drop_state := rand.create(u64(run_seed) ~ 0x10071)
	drop_rng := rand.default_random_generator(&drop_state)

	floor_num := 1
	crypt := generate(run_seed, floor_num)
	defer destroy_dungeon(&crypt)
	world := make_world()
	defer destroy_world(&world)
	knight := populate_floor(&world, crypt, &atlas, floor_num,
	                         carry_hp = 6)

	cam := make_camera({SCREEN_WIDTH, SCREEN_HEIGHT})
	cam.target = room_center(crypt, crypt.start_room)

	coins_collected := 0
	kills := 0
	sword_power: i32 = 1 // sword damage; the green flask raises it
	attack_cooldown: f32
	dbg := init_debug()

	for !rl.WindowShouldClose() {
		// --- Update ---
		debug_update(&dbg)
		dt := rl.GetFrameTime() * dbg.time_scale
		if dbg.enabled {
			vp := compute_viewport(SCREEN_WIDTH, SCREEN_HEIGHT)
			if rl.IsKeyPressed(.T) {
				world.positions[knight.idx] = mouse_world(cam, vp)
			}
			if rl.IsKeyPressed(.E) {
				spawn_enemy(&world, &atlas, mouse_world(cam, vp))
			}
		}
		attack_cooldown -= dt
		if was_pressed(.Attack) && attack_cooldown <= 0 {
			attack_cooldown = ATTACK_COOLDOWN_TIME
			swing_sword(&world, &atlas, knight, sword_power)
		}
		player_input_system(&world, PLAYER_SPEED)
		ai_system(&world, knight, crypt)
		health_system(&world, dt)
		movement_system(&world, crypt.tilemap, dt, dbg.noclip)
		contact_system(&world)
		damage_system(&world)
		for ev in world.damage_events {
			spawn_damage_number(&world, ev)
		}
		for spot in death_system(&world) {
			kills += 1
			d := spawn(&world, {.Position, .Sprite, .Lifetime})
			world.sprites[d.idx] = make_static_sprite(&atlas, "skull", SCALE)
			world.positions[d.idx] = spot
			world.lifetimes[d.idx] = 4
			// The dead pay their respects: one roll on the drop table.
			if kind, dropped := roll(ENEMY_DROPS, drop_rng); dropped {
				spawn_loot(&world, &atlas, spot + {8, 8}, kind)
			}
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
			case .Heart, .Max_Hp, .Power:
				apply_pickup(&world, knight, &sword_power, kind)
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

		// --- Draw, pass 1: the game, at its fixed logical resolution ---
		vp := compute_viewport(SCREEN_WIDTH, SCREEN_HEIGHT)
		rl.BeginTextureMode(target)
		rl.ClearBackground(BACKGROUND_COLOR)
		rl.BeginMode2D(cam)
		tilemap_draw(crypt.tilemap, &atlas, skin)
		draw_system(&world, &atlas)
		draw_floating_texts(&world) // world-space UI rides the camera
		debug_draw_world(dbg, &world)
		rl.EndMode2D()
		debug_draw_panel(dbg, &world, cam, vp)
		draw_hud(&atlas, crypt, room, world.healths[knight.idx],
		         coins_collected, sword_power, floor_num, SCREEN_WIDTH)
		rl.DrawFPS(10, 10)
		rl.EndTextureMode()

		// --- Draw, pass 2: blit the frame, integer-scaled, letterboxed ---
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTexturePro(target.texture,
		                  {0, 0, SCREEN_WIDTH, -SCREEN_HEIGHT}, // RT is stored flipped
		                  vp.dest, {0, 0}, 0, rl.WHITE)
		rl.EndDrawing()

		// Everything on the temp allocator — query results, tprintf
		// names — lives exactly one frame. One sweep returns it all.
		free_all(context.temp_allocator)
	}
}
