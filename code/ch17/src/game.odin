// Chapter 16: the boss and the run. Three floors down, the Warden
// keeps the ring: the seals slam shut behind you, the fight has a
// health bar and a phase flip, and winning is a fifth game phase the
// compiler refused to let us forget.
//
// Web note: there is no `main` here. In a browser, emscripten owns
// the main loop (one requestAnimationFrame per frame), so the game is
// an API instead: game_init once, game_update per frame,
// game_shutdown at the end. The desktop entry point (main_desktop)
// calls the same three procs in a plain loop; the game cannot tell
// who is driving.

package crypt

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
PLAYER_SPEED :: 170
FLOOR_COUNT :: 3 // the run: two floors of dungeon, then the throne
ATTACK_COOLDOWN_TIME :: 0.35
BACKGROUND_COLOR :: rl.Color{24, 20, 37, 255}
RING_COLOR :: rl.Color{232, 193, 112, 255}

// Build with -define:AUTOSTART=true and the menu presses SPACE by
// itself after a second: the chapter 8 lesson (a game you can drive
// without hands) applied to smoke-testing the port.
AUTOSTART :: #config(AUTOSTART, false)

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

Game :: struct {
	// Everything that used to be a local of the main proc. The web
	// build calls game_update once per browser frame, so the frame
	// loop's state has to live somewhere with an address.
	target:    rl.RenderTexture2D,
	atlas:     Atlas,
	skin:      Tile_Skin,
	fx:        Fx,
	bank:      Audio_Bank,
	phase:     Game_Phase,
	crt_on:    bool,
	run:       Run,       // empty until the first game starts
	dust:      Particles, // world debris; survives runs, harmless
	shake:     Shake,
	hitstop:   f32,
	cam:       rl.Camera2D,
	menu_time: f32,
	dbg:       Debug,
	running:   bool,
}

g: Game

destroy_run :: proc(run: ^Run) {
	destroy_world(&run.world)
	destroy_dungeon(&run.crypt)
}

spawn_enemy :: proc(w: ^World, atlas: ^Atlas, pos: rl.Vector2,
                    stats: Enemy_Stats) -> Entity {
	// One archetype from the bestiary, assembled as a component
	// bundle. The caller picks and scales the stats; this proc just
	// builds.
	e := spawn(w, {.Position, .Velocity, .Sprite, .Actor, .Collider,
	               .Bounce, .Health, .Ai, .Contact_Damage})
	w.sprites[e.idx] = make_anim_sprite(atlas, stats.idle_anim,
	                                   SCALE * stats.scale)
	w.actors[e.idx] = {idle_anim = stats.idle_anim,
	                   run_anim = stats.run_anim}
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
	                   run_anim = WARDEN.run_anim}
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
	// this one has been ours since Chapter 1, and the draw pass
	// renders it with the same primitives the title screen uses.
	e := spawn(w, {.Position, .Collider, .Pickup})
	w.positions[e.idx] = pos
	w.colliders[e.idx] = {size = {30, 40}, layer = .Pickup}
	w.pickup_kinds[e.idx] = .Ring
}

spawn_loot :: proc(w: ^World, atlas: ^Atlas, pos: rl.Vector2,
                   kind: Pickup_Kind) {
	// One dropped item where an enemy fell. Drops expire after a
	// while; the crypt keeps a tidy floor.
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
	case .Ring:
		panic("the ring spawns via spawn_ring")
	}
	w.colliders[e.idx] = {
		size  = {sprite_width(w.sprites[e.idx]),
		         sprite_height(w.sprites[e.idx])},
		layer = .Pickup,
	}
	w.pickup_kinds[e.idx] = kind
	w.positions[e.idx] = pos
	w.lifetimes[e.idx] = 12
}

spawn_key :: proc(w: ^World, atlas: ^Atlas, pos: rl.Vector2) {
	// The seal-dissolving flask. Persistent: no lifetime, it waits.
	e := spawn(w, {.Position, .Sprite, .Collider, .Pickup})
	w.sprites[e.idx] = make_static_sprite(atlas, "flask_big_yellow", SCALE)
	w.colliders[e.idx] = {
		size  = {sprite_width(w.sprites[e.idx]),
		         sprite_height(w.sprites[e.idx])},
		layer = .Pickup,
	}
	w.pickup_kinds[e.idx] = .Key
	w.positions[e.idx] = pos
}

swing_sword :: proc(w: ^World, atlas: ^Atlas, player: Entity,
                    damage: i32) {
	// The sword: an entity with a sprite, a hitbox slightly bigger
	// than the blade, one point of damage, and 0.15 seconds to live.
	facing_left := w.sprites[player.idx].flip_x
	e := spawn(w, {.Position, .Sprite, .Collider, .Lifetime,
	               .Contact_Damage})
	w.sprites[e.idx] = make_static_sprite(atlas, "weapon_knight_sword",
	                                      SCALE)
	w.sprites[e.idx].flip_x = facing_left
	px := w.positions[player.idx]
	w.positions[e.idx] = {
		px.x - sprite_width(w.sprites[e.idx]) if facing_left \
			else px.x + sprite_width(w.sprites[player.idx]),
		px.y + 6,
	}
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
	knight := spawn(w, {.Position, .Velocity, .Sprite, .Actor, .Player,
	                    .Collider, .Health})
	w.sprites[knight.idx] = make_anim_sprite(atlas, "knight_m_idle_anim",
	                                         SCALE)
	w.actors[knight.idx] = {idle_anim = "knight_m_idle_anim",
	                        run_anim = "knight_m_run_anim"}
	w.colliders[knight.idx] = feet_collider(w.sprites[knight.idx],
	                                        .Player, hits = {.Pickup})
	w.healths[knight.idx] = {hp = carry_hp, max_hp = 6, invuln_time = 0.8}
	w.positions[knight.idx] = room_center(d, d.start_room) - {16, 28}
	final := floor_num == FLOOR_COUNT
	per_room := min(2 + floor_num, 6)
	for i in 0 ..< len(d.rooms) {
		if i != d.start_room && !(final && i == d.stairs_room) {
			for _ in 0 ..< per_room {
				kind := ENEMY_KINDS[rand.int_max(len(ENEMY_KINDS))]
				spawn_enemy(w, atlas, random_pos_in(d, i),
				            scaled(kind, floor_num))
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
	run.drop_state = rand.create(u64(run.seed ~ 0x10071))
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

counted :: proc(n: int, word: string) -> string {
	// "1 kill" but "2 kills": the two run-summary screens share this
	// so neither of them ever brags about "1 kills".
	return fmt.tprintf("%d %s%s", n, word, "" if n == 1 else "s")
}

draw_centered :: proc(text: cstring, y: i32, size: i32, color: rl.Color) {
	rl.DrawText(text, (SCREEN_WIDTH - rl.MeasureText(text, size)) / 2, y,
	            size, color)
}

game_init :: proc() {
	g.running = true
	when ODIN_OS == .JS {
		// No HIGHDPI flag on the web. The shell already hands us the
		// canvas in device pixels, so the flag could only add broken
		// bookkeeping: raylib's web backend sets its HiDPI draw-scale
		// matrix solely from a browser zoom-change event (so fresh
		// loads never have it), and EndMode2D applies that matrix even
		// inside render textures (so the HUD doubles when it fires).
		// Without the flag, screen, render, canvas, and mouse all
		// agree: one coordinate space, device pixels.
		rl.SetConfigFlags({.WINDOW_RESIZABLE})
	} else {
		rl.SetConfigFlags({.WINDOW_HIGHDPI, .WINDOW_RESIZABLE})
	}
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Crypt of Odin")
	rl.InitAudioDevice()
	rl.SetExitKey(.KEY_NULL) // Esc pauses; it does not quit
	when ODIN_OS != .JS {
		rl.SetTargetFPS(60) // the browser paces frames itself
	}

	g.target = rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
	g.atlas = build_atlas(ART)
	g.skin = make_skin(&g.atlas)
	g.fx = load_fx(&g.atlas, SCREEN_WIDTH, SCREEN_HEIGHT)
	g.bank = load_audio_bank()
	start_music(&g.bank)

	g.phase = .Menu
	g.cam = make_camera({SCREEN_WIDTH, SCREEN_HEIGHT})
	g.dbg = init_debug()
}

game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never call this on the web: WindowShouldClose contains a
		// frame-pacing sleep there, and the browser already paces.
		if rl.WindowShouldClose() {
			g.running = false
		}
	}
	return g.running
}

game_shutdown :: proc() {
	// Everything game_init and the run acquired, released in reverse.
	// A desktop OS would sweep this up at exit anyway; a browser page
	// that embeds and re-embeds the game would not. Deleting a
	// never-started run is fine: its arrays are nil and delete(nil)
	// is a no-op.
	destroy_run(&g.run)
	destroy_particles(&g.dust)
	rl.UnloadRenderTexture(g.target)
	destroy_fx(&g.fx)
	destroy_audio_bank(&g.bank)
	destroy_atlas(&g.atlas)
	rl.CloseAudioDevice()
	rl.CloseWindow()
}

parent_window_size_changed :: proc(w, h: int) {
	// Web only: the browser told us the canvas changed. The letterbox
	// viewport recomputes every frame anyway; raylib just needs to
	// know the new glass size.
	rl.SetWindowSize(i32(w), i32(h))
}

game_update :: proc() {
	audio_update(&g.bank)
	debug_update(&g.dbg)
	// Clamp the frame delta. A backgrounded browser tab or a paused
	// debugger can hand us a multi-second "frame", and a knockback
	// velocity times a huge dt is a teleport through a wall — the
	// axis-separated slide only checks where you landed, not what you
	// crossed. One twentieth of a second keeps the fastest thing in
	// the game well under a tile per step.
	raw_dt := min(rl.GetFrameTime(), 0.05) * g.dbg.time_scale
	// Hitstop: a few frozen frames after a hit. The simulation stops;
	// the shake decay and music do not, or the freeze reads as a bug.
	g.hitstop -= raw_dt
	dt := f32(0) if g.hitstop > 0 else raw_dt
	shake_update(&g.shake, raw_dt)
	vp := compute_viewport(SCREEN_WIDTH, SCREEN_HEIGHT)
	if was_pressed(.Crt) {   // a display setting, so it works in
		g.crt_on = !g.crt_on // every phase, even on the title screen
	}

	// --- Update, by phase ---
	switch g.phase {
	case .Menu:
		g.menu_time += dt
		if was_pressed(.Attack) || (AUTOSTART && g.menu_time > 1) {
			g.run = new_run(&g.atlas)
			g.cam.target = room_center(g.run.crypt, g.run.crypt.start_room)
			g.phase = .Playing
			play(&g.bank, .Start)
		}
	case .Paused:
		if was_pressed(.Pause) || was_pressed(.Attack) {
			g.phase = .Playing
		}
	case .Game_Over, .Victory:
		if was_pressed(.Attack) {
			destroy_run(&g.run)
			g.run = new_run(&g.atlas)
			g.cam.target = room_center(g.run.crypt, g.run.crypt.start_room)
			g.phase = .Playing
			play(&g.bank, .Start)
		}
	case .Playing:
		if was_pressed(.Pause) {
			g.phase = .Paused
		}
		if g.dbg.enabled {
			if rl.IsKeyPressed(.T) {
				g.run.world.positions[g.run.knight.idx] = mouse_world(g.cam, vp)
			}
			if rl.IsKeyPressed(.E) {
				kind := ENEMY_KINDS[rand.int_max(len(ENEMY_KINDS))]
				spawn_enemy(&g.run.world, &g.atlas, mouse_world(g.cam, vp),
				            scaled(kind, g.run.floor_num))
			}
		}
		g.run.attack_cooldown -= dt
		if was_pressed(.Attack) && g.run.attack_cooldown <= 0 {
			g.run.attack_cooldown = ATTACK_COOLDOWN_TIME
			swing_sword(&g.run.world, &g.atlas, g.run.knight,
			            g.run.sword_power)
			play(&g.bank, .Swing)
		}
		player_input_system(&g.run.world, PLAYER_SPEED)
		ai_system(&g.run.world, g.run.knight, g.run.crypt)
		// --- the boss's turn: phase flip and minion calls ---
		boss_pos: rl.Vector2
		boss_idx := find_boss(&g.run.world)
		if boss_idx >= 0 {
			boss_pos = g.run.world.positions[boss_idx] +
				rl.Vector2{sprite_width(g.run.world.sprites[boss_idx]) / 2,
				           sprite_height(g.run.world.sprites[boss_idx]) / 2}
			was_calm := g.run.world.bosses[boss_idx].phase == .Stalk
			for spot in boss_system(&g.run.world, dt) {
				// Cap the court: only creatures in the throne room
				// count, or the rest of the floor's population blocks
				// the calls.
				court := 0
				for i in query(&g.run.world, {.Ai}) {
					if room_at(g.run.crypt, g.run.world.positions[i]) ==
					   g.run.crypt.stairs_room {
						court += 1
					}
				}
				if court <= 4 { // the Warden counts as one
					spawn_enemy(&g.run.world, &g.atlas, spot + {40, 40},
					            scaled(IMP, g.run.floor_num))
					emit_burst(&g.dust, spot + {56, 56}, 8,
					           {160, 60, 200, 255},
					           speed = 90, life_secs = 0.4)
				}
			}
			if was_calm && g.run.world.bosses[boss_idx].phase == .Enrage {
				play(&g.bank, .Roar) // half health: the fight changes
				add_trauma(&g.shake, 0.5)
			}
		}
		health_system(&g.run.world, dt)
		movement_system(&g.run.world, g.run.crypt.tilemap, dt, g.dbg.noclip)
		hp_before := g.run.world.healths[g.run.knight.idx].hp
		contact_system(&g.run.world)
		damage_system(&g.run.world)
		if len(g.run.world.damage_events) > 0 {
			play(&g.bank, .Hit)
			g.hitstop = 0.05 // three frames of impact
			add_trauma(&g.shake, 0.2)
		}
		if g.run.world.healths[g.run.knight.idx].hp < hp_before {
			add_trauma(&g.shake, 0.35) // our pain shakes harder
		}
		for ev in g.run.world.damage_events {
			spawn_damage_number(&g.run.world, ev)
			emit_burst(&g.dust, ev.pos, 6, {255, 200, 100, 255},
			           speed = 70, life_secs = 0.35)
		}
		for spot in death_system(&g.run.world) {
			g.run.kills += 1
			play(&g.bank, .Kill)
			g.hitstop = 0.09 // deaths hit harder
			add_trauma(&g.shake, 0.3)
			emit_burst(&g.dust, spot + {16, 16}, 18, {200, 60, 60, 255},
			           speed = 110, life_secs = 0.6)
			d := spawn(&g.run.world, {.Position, .Sprite, .Lifetime})
			g.run.world.sprites[d.idx] = make_static_sprite(&g.atlas,
			                                                "skull", SCALE)
			g.run.world.positions[d.idx] = spot
			g.run.world.lifetimes[d.idx] = 4
			drop_rng := rand.default_random_generator(&g.run.drop_state)
			if drop, dropped := roll(ENEMY_DROPS, drop_rng); dropped {
				spawn_loot(&g.run.world, &g.atlas, spot + {8, 8}, drop)
			}
		}
		if boss_idx >= 0 && find_boss(&g.run.world) < 0 {
			// The Warden fell: the long freeze, the seals dissolve,
			// and the ring is suddenly just lying there.
			g.hitstop = 0.25
			add_trauma(&g.shake, 0.9)
			emit_burst(&g.dust, boss_pos, 40, RING_COLOR, speed = 160,
			           life_secs = 0.9)
			spawn_ring(&g.run.world, boss_pos - {15, 15})
			unlock(&g.run.crypt)
			play(&g.bank, .Unlock)
		}
		if g.run.world.healths[g.run.knight.idx].hp <= 0 {
			g.phase = .Game_Over // death means something now
			play(&g.bank, .Game_Over)
		}
		for kind in pickup_system(&g.run.world) {
			switch kind {
			case .Ring:
				g.phase = .Victory // the fifth arm the compiler demanded
				play(&g.bank, .Victory)
			case .Coin:
				g.run.coins += 1
				play(&g.bank, .Coin)
			case .Key:
				unlock(&g.run.crypt)
				play(&g.bank, .Unlock)
			case .Heart:
				apply_pickup(&g.run.world, g.run.knight,
				             &g.run.sword_power, kind)
				play(&g.bank, .Heart)
			case .Max_Hp, .Power:
				apply_pickup(&g.run.world, g.run.knight,
				             &g.run.sword_power, kind)
				play(&g.bank, .Power)
			}
		}
		hover_system(&g.run.world, mouse_world(g.cam, vp))
		actor_anim_system(&g.run.world, &g.atlas)
		animation_system(&g.run.world, dt)
		lifetime_system(&g.run.world, dt)
		particles_update(&g.dust, dt) // frozen by hitstop, like the world
		feet := collider_rect(&g.run.world, g.run.knight.idx)
		if tile_at(g.run.crypt.tilemap,
		           i32(feet.x + feet.width / 2) / TILE_SIZE,
		           i32(feet.y + feet.height / 2) / TILE_SIZE) == .Stairs {
			descend(&g.run, &g.atlas)
			play(&g.bank, .Stairs)
			destroy_particles(&g.dust)
			g.dust = {} // new floor, clean air
		}
		knight_center := g.run.world.positions[g.run.knight.idx] +
			rl.Vector2{sprite_width(g.run.world.sprites[g.run.knight.idx]) / 2,
			           sprite_height(g.run.world.sprites[g.run.knight.idx]) / 2}
		room := room_at(g.run.crypt, knight_center)
		if find_boss(&g.run.world) >= 0 && room == g.run.crypt.stairs_room &&
		   !is_locked(g.run.crypt) &&
		   inside_room(g.run.crypt, g.run.crypt.stairs_room, knight_center) {
			relock(&g.run.crypt)    // no stairs behind the Warden,
			play(&g.bank, .Stairs)  // and now no door behind you
			add_trauma(&g.shake, 0.4)
		}
		cam_target := room_center(g.run.crypt, room) if room >= 0 \
			else knight_center
		camera_follow(&g.cam, cam_target, pixel_size(g.run.crypt.tilemap),
		              dt, speed = 6)
	}

	// --- Draw, pass 1: the frame, at its fixed logical resolution ---
	rl.BeginTextureMode(g.target)
	rl.ClearBackground(BACKGROUND_COLOR)
	if g.phase == .Menu {
		bob := i32(10 * math.sin(g.menu_time * math.PI))
		draw_ring(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 - 40 + bob)
		draw_centered("CRYPT OF ODIN", 300, 40, RING_COLOR)
		draw_centered("press SPACE to descend", 350, 20, rl.LIGHTGRAY)
		draw_centered("WASD moves, SPACE swings, ESC pauses, C for CRT",
		              380, 10, rl.GRAY)
	} else {
		// The camera drawn through this frame's shake displacement;
		// the real camera never moves, so the shake leaves no drift
		// behind.
		shaken_cam := g.cam
		shaken_cam.target = g.cam.target + shake_offset(g.shake)
		rl.BeginMode2D(shaken_cam)
		tilemap_draw(g.run.crypt.tilemap, &g.atlas, g.skin)
		draw_system(&g.run.world, &g.atlas, g.fx)
		for i in query(&g.run.world, {.Pickup, .Position}) {
			if g.run.world.pickup_kinds[i] == .Ring {
				draw_ring(i32(g.run.world.positions[i].x) + 15,
				           i32(g.run.world.positions[i].y) + 15, 0.32)
			}
		}
		particles_draw(g.dust)
		draw_floating_texts(&g.run.world)
		debug_draw_world(g.dbg, &g.run.world)
		rl.EndMode2D()
		if g.run.world.hovered >= 0 {
			m := mouse_logical(vp)
			rl.DrawText(fmt.ctprintf("%s",
				label(g.run.world.pickup_kinds[g.run.world.hovered])),
				i32(m.x) + 14, i32(m.y) - 6, 16, rl.RAYWHITE)
		}
		debug_draw_panel(g.dbg, &g.run.world, g.cam, vp)
		draw_hud(&g.atlas, g.run.crypt,
		         room_at(g.run.crypt, g.run.world.positions[g.run.knight.idx]),
		         g.run.world.healths[g.run.knight.idx], g.run.coins,
		         g.run.sword_power, g.run.floor_num, SCREEN_WIDTH)
		boss_now := find_boss(&g.run.world)
		if boss_now >= 0 &&
		   room_at(g.run.crypt, g.run.world.positions[g.run.knight.idx]) ==
		   g.run.crypt.stairs_room {
			draw_boss_bar("THE WARDEN",
			              g.run.world.healths[boss_now].hp,
			              g.run.world.healths[boss_now].max_hp,
			              SCREEN_WIDTH, SCREEN_HEIGHT)
		}
		rl.DrawFPS(10, 10)
		if g.phase == .Paused {
			rl.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT,
			                 {0, 0, 0, 160})
			draw_centered("PAUSED", 200, 40, rl.RAYWHITE)
			draw_centered("ESC resumes", 250, 20, rl.LIGHTGRAY)
			draw_centered("C toggles the CRT filter", 280, 10, rl.GRAY)
		} else if g.phase == .Game_Over {
			rl.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT,
			                 {0, 0, 0, 190})
			draw_centered("THE CRYPT KEEPS THE RING", 160, 30, rl.RED)
			draw_centered(fmt.ctprintf("floor %d  |  %s  |  %s",
				g.run.floor_num, counted(g.run.kills, "kill"),
				counted(g.run.coins, "coin")), 220, 20, rl.LIGHTGRAY)
			draw_centered("press SPACE to try again", 270, 20, rl.GOLD)
		} else if g.phase == .Victory {
			rl.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT,
			                 {0, 0, 0, 190})
			draw_ring(SCREEN_WIDTH / 2, 140)
			draw_centered("DRAUPNIR RETURNS", 250, 30, RING_COLOR)
			draw_centered(fmt.ctprintf("%d floors  |  %s  |  %s",
				FLOOR_COUNT, counted(g.run.kills, "kill"),
				counted(g.run.coins, "coin")), 300, 20, rl.LIGHTGRAY)
			draw_centered("press SPACE to run it back", 340, 20, rl.GOLD)
		}
	}
	rl.EndTextureMode()

	// --- Draw, pass 2: blit, integer-scaled, letterboxed ---
	// The CRT shader wraps only the blit: post-processing is exactly
	// "draw the finished frame through a fragment shader".
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	if g.crt_on {
		rl.BeginShaderMode(g.fx.crt)
	}
	rl.DrawTexturePro(g.target.texture,
		{0, 0, f32(SCREEN_WIDTH), -f32(SCREEN_HEIGHT)},
		vp.dest, {0, 0}, 0, rl.WHITE)
	if g.crt_on {
		rl.EndShaderMode()
	}
	rl.EndDrawing()

	// Anything on the temp allocator (queries, ctprintf strings) is
	// invalid after this line; the frame is over.
	free_all(context.temp_allocator)
}
