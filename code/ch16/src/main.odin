// Chapter 16: the boss and the run. Three floors down, the Warden
// keeps the ring: the seals slam shut behind you, the fight has a
// health bar and a phase flip, and winning is a fifth game phase the
// compiler refused to let us forget. Everything the boss does is
// assembled from parts the previous fifteen chapters already built.

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
FLOOR_COUNT :: 3 // the run: two floors of dungeon, then the throne

Game_Phase :: enum {
	Menu, Playing, Paused, Game_Over, Victory,
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

spawn_enemy :: proc(w: ^World, atlas: ^Atlas, pos: rl.Vector2,
                    stats: Enemy_Stats) -> Entity {
	// One archetype from the bestiary, assembled as a component
	// bundle. The caller picks and scales the stats; this proc just
	// builds. Returns the entity so debug mode can reposition it.
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

spawn_boss :: proc(w: ^World, atlas: ^Atlas, pos: rl.Vector2) -> Entity {
	// The Warden: the ordinary enemy bundle plus .Boss and bigger
	// everything. It reuses Ai wholesale (chasing is chasing); the
	// boss system only layers phases on top.
	e := spawn(w, {.Position, .Velocity, .Sprite, .Actor, .Collider,
	               .Health, .Ai, .Contact_Damage, .Boss})
	w.sprites[e.idx] = make_anim_sprite(atlas, WARDEN.idle_anim,
	                                   SCALE * WARDEN.scale)
	w.actors[e.idx] = {idle_anim = WARDEN.idle_anim,
	                   run_anim  = WARDEN.run_anim}
	w.colliders[e.idx] = feet_collider(w.sprites[e.idx], .Enemy,
	                                   hits = {.Player})
	w.healths[e.idx] = {hp = WARDEN.hp, max_hp = WARDEN.hp,
	                    invuln_time = 0.15}
	w.ais[e.idx] = {chase_speed = WARDEN.speed, aggro = WARDEN.aggro}
	w.contact_damages[e.idx] = {amount = 1, knockback = 350}
	w.positions[e.idx] = pos
	return e
}

spawn_ring :: proc(w: ^World, pos: rl.Vector2) {
	// The win condition, as an entity: position, collider, pickup, and
	// no sprite at all. Nobody drew a ring sprite, and nobody should:
	// this one has been ours since Chapter 1, and the draw pass renders
	// it with the same primitives the title screen uses.
	e := spawn(w, {.Position, .Collider, .Pickup})
	w.positions[e.idx] = pos
	w.colliders[e.idx] = {size = {30, 40}, layer = .Pickup}
	w.pickup_kinds[e.idx] = .Ring
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
	case .Ring:  panic("the ring spawns via spawn_ring")
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

	final := floor_num == FLOOR_COUNT
	per_room := min(2 + floor_num, 6)
	for i in 0 ..< len(d.rooms) {
		if i != d.start_room && !(final && i == d.stairs_room) {
			for _ in 0 ..< per_room {
				spawn_enemy(w, atlas, random_pos_in(d, i),
				            scaled(ENEMY_KINDS[rand.int_max(len(ENEMY_KINDS))],
				                   floor_num))
			}
		}
	}
	if final {
		// The centering offset is half the boss's drawn size: 16px art
		// at WARDEN.scale (2) * SCALE (2) draws 64x64, so {32, 32}
		// (an earlier, non-square boss sprite needed 32x36 here).
		spawn_boss(w, atlas, room_center(d, d.stairs_room) - {32, 32})
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
	run.crypt = generate(run.seed, 1, final = FLOOR_COUNT == 1)
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
	                     run.floor_num,
	                     final = run.floor_num == FLOOR_COUNT)
	destroy_world(&run.world)
	run.world = make_world()
	run.knight = populate_floor(&run.world, run.crypt, atlas,
	                            run.floor_num, carry_hp = hp)
}

draw_ring :: proc(cx, cy: i32, s: f32 = 1) {
	// The Chapter 1 ring, drawn at any size: full for the title and
	// victory screens, a third for the item lying in the throne room.
	// Some programmer art is family.
	x, y := f32(cx), f32(cy)
	rl.DrawRing({x, y}, 30 * s, 45 * s, 0, 360, 48, RING_COLOR)
	for i in 0 ..< 3 {
		drop := rl.Vector2{x + (f32(i) - 1) * 26 * s,
		                   y + (62 + f32(i % 2) * 10) * s}
		rl.DrawRing(drop, 4 * s, 7 * s, 0, 360, 24, RING_COLOR)
	}
	gx, gy := x + 26 * s, y - 26 * s
	rl.DrawTriangle({gx - 7 * s, gy}, {gx + 7 * s, gy}, {gx, gy - 14 * s},
	                rl.RAYWHITE)
	rl.DrawTriangle({gx + 7 * s, gy}, {gx - 7 * s, gy}, {gx, gy + 14 * s},
	                rl.RAYWHITE)
	rl.DrawCircle(cx, cy + i32(37 * s), 9 * s, {165, 48, 48, 255})
}

draw_centered :: proc(text: cstring, y, size: i32, color: rl.Color) {
	rl.DrawText(text, (SCREEN_WIDTH - rl.MeasureText(text, size)) / 2, y,
	            size, color)
}

counted :: proc(n: int, word: string) -> string {
	// "1 kill" but "2 kills": the two run-summary screens share this so
	// neither of them ever brags about "1 kills".
	suffix := "" if n == 1 else "s"
	return fmt.tprintf("%d %s%s", n, word, suffix)
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
		case .Game_Over, .Victory:
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
					spawn_enemy(&run.world, &atlas, mouse_world(cam, vp),
					            scaled(ENEMY_KINDS[rand.int_max(len(ENEMY_KINDS))],
					                   run.floor_num))
				}
			}
			run.attack_cooldown -= dt
			if was_pressed(.Attack) && run.attack_cooldown <= 0 {
				run.attack_cooldown = ATTACK_COOLDOWN_TIME
				swing_sword(&run.world, &atlas, run.knight, run.sword_power)
				play(&bank, .Swing)
			}
			// --- the boss's turn: phase flip and minion calls ---
			boss_pos: rl.Vector2
			boss_idx := find_boss(&run.world)
			if boss_idx >= 0 {
				boss_pos = run.world.positions[boss_idx] + {32, 36}
				was_calm := run.world.bosses[boss_idx].phase == .Stalk
				for spot in boss_system(&run.world, dt) {
					// Cap the court: only creatures in the throne room
					// count, or the rest of the floor's population
					// blocks the calls.
					court := 0
					for i in query(&run.world, {.Ai}) {
						if room_at(run.crypt, run.world.positions[i]) ==
						   run.crypt.stairs_room {
							court += 1
						}
					}
					if court <= 4 { // the Warden counts as one
						spawn_enemy(&run.world, &atlas, spot + {40, 40},
						            scaled(IMP, run.floor_num))
						emit_burst(&dust, spot + {56, 56}, 8,
						           {160, 60, 200, 255},
						           speed = 90, life_secs = 0.4)
					}
				}
				if was_calm && run.world.bosses[boss_idx].phase == .Enrage {
					play(&bank, .Roar) // half health: the fight changes
					add_trauma(&shake, 0.5)
				}
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
			if boss_idx >= 0 && find_boss(&run.world) < 0 {
				// The Warden fell: the long freeze, the seals dissolve,
				// and the ring is suddenly just lying there.
				hitstop = 0.25
				add_trauma(&shake, 0.9)
				emit_burst(&dust, boss_pos, 40, RING_COLOR,
				           speed = 160, life_secs = 0.9)
				spawn_ring(&run.world, boss_pos - {15, 15})
				unlock(&run.crypt)
				play(&bank, .Unlock)
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
				case .Ring:
					phase = .Victory // the fifth arm the compiler demanded
					play(&bank, .Victory)
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
			if find_boss(&run.world) >= 0 && room == run.crypt.stairs_room &&
			   !is_locked(run.crypt) &&
			   inside_room(run.crypt, run.crypt.stairs_room, knight_center) {
				relock(&run.crypt)  // no stairs behind the Warden,
				play(&bank, .Stairs) // and now no door behind you
				add_trauma(&shake, 0.4)
			}
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
			for i in query(&run.world, {.Pickup, .Position}) {
				if run.world.pickup_kinds[i] == .Ring {
					draw_ring(i32(run.world.positions[i].x) + 15,
					           i32(run.world.positions[i].y) + 15, 0.32)
				}
			}
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
			boss_now := find_boss(&run.world)
			if boss_now >= 0 &&
			   room_at(run.crypt, run.world.positions[run.knight.idx]) ==
			   run.crypt.stairs_room {
				draw_boss_bar("THE WARDEN", run.world.healths[boss_now].hp,
				              run.world.healths[boss_now].max_hp,
				              SCREEN_WIDTH, SCREEN_HEIGHT)
			}
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
				draw_centered(fmt.ctprintf("floor %d  |  %s  |  %s",
				                           run.floor_num,
				                           counted(run.kills, "kill"),
				                           counted(run.coins, "coin")),
				              220, 20, rl.LIGHTGRAY)
				draw_centered("press SPACE to try again", 270, 20, rl.GOLD)
			} else if phase == .Victory {
				rl.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT,
				                 {0, 0, 0, 190})
				draw_ring(SCREEN_WIDTH / 2, 140)
				draw_centered("DRAUPNIR RETURNS", 250, 30, RING_COLOR)
				draw_centered(fmt.ctprintf("%d floors  |  %s  |  %s",
				                           FLOOR_COUNT,
				                           counted(run.kills, "kill"),
				                           counted(run.coins, "coin")),
				              300, 20, rl.LIGHTGRAY)
				draw_centered("press SPACE to run it back", 340, 20, rl.GOLD)
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
