// Chapter 15: the GPU joins the party. Two fragment shaders: a gold
// outline on whatever pickup the mouse hovers (with a label, so it is
// UI and not just a demo), and a togglable CRT filter over the whole
// frame — curvature, scanlines, vignette — riding the Chapter 12
// canvas, which turns out to have been a post-processing rig all along.

package crypt

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
BACKGROUND_COLOR :: rl.Color{24, 20, 37, 255}
RING_COLOR :: rl.Color{232, 193, 112, 255}
PLAYER_SPEED :: 170
ATTACK_COOLDOWN_TIME :: 0.35

Game_Phase :: enum {
	Menu, Playing, Paused, Game_Over,
}

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

Run :: struct {
	// Everything one playthrough owns. Starting over is constructing
	// a new Run; the only cleanup anywhere is handing the old one's
	// arrays back (destroy_run).
	world:           World,
	crypt:           Dungeon,
	knight:          Entity,
	floor_num:       int,
	coins, kills:    int,
	sword_power:     i32,
	attack_cooldown: f32,
	seed:            i64,
	drop_state:      rand.Default_Random_State,
}

destroy_run :: proc(run: ^Run) {
	destroy_world(&run.world)
	destroy_dungeon(&run.crypt)
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

spawn_loot :: proc(w: ^World, atlas: ^Atlas, pos: rl.Vector2,
                   kind: Pickup_Kind) {
	// One dropped item where an enemy fell. Drops expire after a while;
	// the crypt keeps a tidy floor.
	e := spawn(w, {.Position, .Sprite, .Lifetime, .Collider, .Pickup})
	switch kind {
	case .Coin:
		w.sprites[e.idx] = make_anim_sprite(atlas, "coin_anim", SCALE)
	case .Heart:
		w.sprites[e.idx] = make_static_sprite(atlas, "ui_heart_full", SCALE)
	case .Max_Hp:
		w.sprites[e.idx] = make_static_sprite(atlas, "flask_big_blue", SCALE)
	case .Power:
		w.sprites[e.idx] = make_static_sprite(atlas, "flask_big_green", SCALE)
	case .Key:
		w.sprites[e.idx] = make_static_sprite(atlas, "flask_big_yellow", SCALE)
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

new_run :: proc(atlas: ^Atlas) -> (run: Run) {
	// A whole playthrough, built from one seed.
	run.seed = i64(rand.int_max(1_000_000))
	fmt.println("run seed:", run.seed)
	run.floor_num = 1
	run.sword_power = 1
	run.drop_state = rand.create(u64(run.seed) ~ 0x10071)
	run.world = make_world()
	run.crypt = generate(run.seed, 1)
	run.knight = populate_floor(&run.world, run.crypt, atlas, 1,
	                            carry_hp = 6)
	return
}

descend :: proc(run: ^Run, atlas: ^Atlas) {
	// Down the stairs: a fresh floor, one deeper, hp carried along.
	run.floor_num += 1
	hp := run.world.healths[run.knight.idx].hp
	destroy_dungeon(&run.crypt)
	run.crypt = generate(run.seed + i64(run.floor_num) * 7919,
	                     run.floor_num)
	destroy_world(&run.world)
	run.world = make_world()
	run.knight = populate_floor(&run.world, run.crypt, atlas,
	                            run.floor_num, carry_hp = hp)
}

draw_ring :: proc(cx, cy: i32) {
	// The Chapter 1 ring, back for the title screen. Some programmer
	// art is family.
	rl.DrawRing({f32(cx), f32(cy)}, 30, 45, 0, 360, 48, RING_COLOR)
	for i in i32(0) ..< 3 {
		drop := rl.Vector2{f32(cx + (i - 1) * 26), f32(cy + 62 + (i % 2) * 10)}
		rl.DrawRing(drop, 4, 7, 0, 360, 24, RING_COLOR)
	}
	gx, gy := f32(cx) + 26, f32(cy) - 26
	rl.DrawTriangle({gx - 7, gy}, {gx + 7, gy}, {gx, gy - 14}, rl.RAYWHITE)
	rl.DrawTriangle({gx + 7, gy}, {gx - 7, gy}, {gx, gy + 14}, rl.RAYWHITE)
	rl.DrawCircle(cx, cy + 37, 9, {165, 48, 48, 255})
}

draw_centered :: proc(text: cstring, y, size: i32, color: rl.Color) {
	rl.DrawText(text, (SCREEN_WIDTH - rl.MeasureText(text, size)) / 2, y,
	            size, color)
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_HIGHDPI, .WINDOW_RESIZABLE})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Crypt of Odin")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()
	rl.SetExitKey(.KEY_NULL) // Esc pauses; it does not quit

	target := rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
	defer rl.UnloadRenderTexture(target)

	atlas := build_atlas(ART)
	defer destroy_atlas(&atlas)
	skin := make_skin(&atlas)
	fx := load_fx(&atlas, SCREEN_WIDTH, SCREEN_HEIGHT)
	defer destroy_fx(&fx)
	bank := load_audio_bank()
	defer destroy_audio_bank(&bank)
	start_music(&bank)

	phase := Game_Phase.Menu
	run: Run // empty until the first game starts
	defer destroy_run(&run)
	cam := make_camera({SCREEN_WIDTH, SCREEN_HEIGHT})
	menu_time: f32
	dust: Particles // world debris; survives runs, harmless
	defer destroy_particles(&dust)
	shake: Shake
	hitstop: f32
	crt_on := false
	dbg := init_debug()

	for !rl.WindowShouldClose() {
		audio_update(&bank)
		debug_update(&dbg)
		// The frame delta, capped: a backgrounded tab or a paused
		// debugger must not hand knockback a whole-tile timestep.
		raw_dt := min(rl.GetFrameTime(), 0.05) * dbg.time_scale
		// Hitstop: a few frozen frames after a hit. The simulation
		// stops; the shake decay and music do not, or the freeze reads
		// as a bug.
		hitstop -= raw_dt
		dt := raw_dt
		if hitstop > 0 {
			dt = 0
		}
		shake_update(&shake, raw_dt)
		vp := compute_viewport(SCREEN_WIDTH, SCREEN_HEIGHT)
		if was_pressed(.Crt) { // a display setting, so it works in
			crt_on = !crt_on   // every phase, even on the title screen
		}

		// --- Update, by phase ---
		switch phase {
		case .Menu:
			menu_time += dt
			if was_pressed(.Attack) {
				destroy_run(&run)
				run = new_run(&atlas)
				cam.target = room_center(run.crypt, run.crypt.start_room)
				phase = .Playing
				play(&bank, .Start)
			}
		case .Paused:
			if was_pressed(.Pause) || was_pressed(.Attack) {
				phase = .Playing
			}
		case .Game_Over:
			if was_pressed(.Attack) {
				destroy_run(&run)
				run = new_run(&atlas)
				cam.target = room_center(run.crypt, run.crypt.start_room)
				phase = .Playing
				play(&bank, .Start)
			}
		case .Playing:
			if was_pressed(.Pause) {
				phase = .Paused
			}
			if dbg.enabled {
				if rl.IsKeyPressed(.T) {
					run.world.positions[run.knight.idx] = mouse_world(cam, vp)
				}
				if rl.IsKeyPressed(.E) {
					spawn_enemy(&run.world, &atlas, mouse_world(cam, vp))
				}
			}
			run.attack_cooldown -= dt
			if was_pressed(.Attack) && run.attack_cooldown <= 0 {
				run.attack_cooldown = ATTACK_COOLDOWN_TIME
				swing_sword(&run.world, &atlas, run.knight, run.sword_power)
				play(&bank, .Swing)
			}
			player_input_system(&run.world, PLAYER_SPEED)
			ai_system(&run.world, run.knight, run.crypt)
			health_system(&run.world, dt)
			movement_system(&run.world, run.crypt.tilemap, dt, dbg.noclip)
			contact_system(&run.world)
			hp_before := run.world.healths[run.knight.idx].hp
			damage_system(&run.world)
			if len(run.world.damage_events) > 0 {
				play(&bank, .Hit)
				hitstop = 0.05 // three frames of impact
				add_trauma(&shake, 0.2)
			}
			if run.world.healths[run.knight.idx].hp < hp_before {
				add_trauma(&shake, 0.35) // our pain shakes harder
			}
			for ev in run.world.damage_events {
				spawn_damage_number(&run.world, ev)
				emit_burst(&dust, ev.pos, 6, {255, 200, 100, 255},
				           speed = 70, life_secs = 0.35)
			}
			for spot in death_system(&run.world) {
				run.kills += 1
				play(&bank, .Kill)
				hitstop = 0.09 // deaths hit harder
				add_trauma(&shake, 0.3)
				emit_burst(&dust, spot + {16, 16}, 18,
				           {200, 60, 60, 255},
				           speed = 110, life_secs = 0.6)
				d := spawn(&run.world, {.Position, .Sprite, .Lifetime})
				run.world.sprites[d.idx] = make_static_sprite(&atlas,
				                                              "skull", SCALE)
				run.world.positions[d.idx] = spot
				run.world.lifetimes[d.idx] = 4
				drop_rng := rand.default_random_generator(&run.drop_state)
				if kind, dropped := roll(ENEMY_DROPS, drop_rng); dropped {
					spawn_loot(&run.world, &atlas, spot + {8, 8}, kind)
				}
			}
			if run.world.healths[run.knight.idx].hp <= 0 {
				phase = .Game_Over // death means something now
				play(&bank, .Game_Over)
			}
			for kind in pickup_system(&run.world) {
				switch kind {
				case .Coin:
					run.coins += 1
					play(&bank, .Coin)
				case .Key:
					unlock(&run.crypt)
					play(&bank, .Unlock)
				case .Heart:
					apply_pickup(&run.world, run.knight,
					             &run.sword_power, kind)
					play(&bank, .Heart)
				case .Max_Hp, .Power:
					apply_pickup(&run.world, run.knight,
					             &run.sword_power, kind)
					play(&bank, .Power)
				}
			}
			actor_anim_system(&run.world, &atlas)
			animation_system(&run.world, dt)
			lifetime_system(&run.world, dt)
			particles_update(&dust, dt) // frozen by hitstop, like the world

			feet := collider_rect(&run.world, run.knight.idx)
			if tile_at(run.crypt.tilemap,
			           tile_coord(feet.x + feet.width / 2),
			           tile_coord(feet.y + feet.height / 2)) == .Stairs {
				descend(&run, &atlas)
				play(&bank, .Stairs)
				destroy_particles(&dust)
				dust = {} // new floor, clean air
				cam.target = room_center(run.crypt, run.crypt.start_room)
			}

			knight_center := run.world.positions[run.knight.idx] + rl.Vector2{
				sprite_width(run.world.sprites[run.knight.idx]) / 2,
				sprite_height(run.world.sprites[run.knight.idx]) / 2,
			}
			room := room_at(run.crypt, knight_center)
			cam_target := knight_center
			if room >= 0 {
				cam_target = room_center(run.crypt, room)
			}
			camera_follow(&cam, cam_target, pixel_size(run.crypt.tilemap),
			              dt, speed = 6)
			hover_system(&run.world, mouse_world(cam, vp))
		}

		// --- Draw, pass 1: the frame, at its fixed logical resolution ---
		rl.BeginTextureMode(target)
		rl.ClearBackground(BACKGROUND_COLOR)
		if phase == .Menu {
			bob := i32(10 * math.sin(menu_time * math.PI))
			draw_ring(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 - 40 + bob)
			draw_centered("CRYPT OF ODIN", 300, 40, RING_COLOR)
			draw_centered("press SPACE to descend", 350, 20, rl.LIGHTGRAY)
			draw_centered("WASD moves, SPACE swings, ESC pauses, C for CRT",
			              380, 10, rl.GRAY)
		} else {
			// The camera drawn through this frame's shake displacement;
			// the real camera never moves, so the shake leaves no drift
			// behind.
			shaken_cam := cam
			shaken_cam.target = cam.target + shake_offset(shake)
			rl.BeginMode2D(shaken_cam)
			tilemap_draw(run.crypt.tilemap, &atlas, skin)
			draw_system(&run.world, &atlas, fx)
			particles_draw(dust)
			draw_floating_texts(&run.world)
			debug_draw_world(dbg, &run.world)
			rl.EndMode2D()
			debug_draw_panel(dbg, &run.world, cam, vp)
			if run.world.hovered >= 0 {
				m := mouse_logical(vp)
				rl.DrawText(fmt.ctprintf("%s",
				            label(run.world.pickup_kinds[run.world.hovered])),
				            i32(m.x) + 14, i32(m.y) - 6, 16, rl.RAYWHITE)
			}
			draw_hud(&atlas, run.crypt,
			         room_at(run.crypt, run.world.positions[run.knight.idx]),
			         run.world.healths[run.knight.idx], run.coins,
			         run.sword_power, run.floor_num, SCREEN_WIDTH)
			rl.DrawFPS(10, 10)
			if phase == .Paused {
				rl.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT,
				                 {0, 0, 0, 160})
				draw_centered("PAUSED", 200, 40, rl.RAYWHITE)
				draw_centered("ESC resumes", 250, 20, rl.LIGHTGRAY)
				draw_centered("C toggles the CRT filter", 280, 10, rl.GRAY)
			} else if phase == .Game_Over {
				rl.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT,
				                 {0, 0, 0, 190})
				draw_centered("THE CRYPT KEEPS THE RING", 160, 30, rl.RED)
				draw_centered(fmt.ctprintf("floor %d  |  %d kills  |  %d coins",
				                           run.floor_num, run.kills,
				                           run.coins), 220, 20, rl.LIGHTGRAY)
				draw_centered("press SPACE to try again", 270, 20, rl.GOLD)
			}
		}
		rl.EndTextureMode()

		// --- Draw, pass 2: blit, integer-scaled, letterboxed ---
		// The CRT shader wraps only the blit: post-processing is
		// exactly "draw the finished frame through a fragment shader".
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		if crt_on {
			rl.BeginShaderMode(fx.crt)
		}
		rl.DrawTexturePro(target.texture,
		                  {0, 0, SCREEN_WIDTH, -SCREEN_HEIGHT},
		                  vp.dest, {0, 0}, 0, rl.WHITE)
		if crt_on {
			rl.EndShaderMode()
		}
		rl.EndDrawing()

		// Everything on the temp allocator — query results, tprintf
		// names — lives exactly one frame. One sweep returns it all.
		free_all(context.temp_allocator)
	}
}
