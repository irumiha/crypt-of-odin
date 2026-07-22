// Systems: procs that each run one query and do one job. The frame
// loop calls them in a fixed order; that list (in main.odin) is the
// entire control flow of the game — no system calls another.
//
// Data flows between systems implicitly (one writes state, a later one
// reads it), which is why every system below declares what it reads
// and writes. Keep those lines accurate when editing.

package crypt

import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

player_input_system :: proc(w: ^World, speed: f32) {
	// Turns the player's held keys into velocity, overwriting whatever
	// was there: the player moves exactly as told, every frame. While
	// stunned, knockback owns the velocity and input waits.
	// Reads: the keyboard (via the action map), Health. Writes: Velocity.
	for i in query(w, {.Player, .Velocity}) {
		if !(has(w, i, .Health) && w.healths[i].stun > 0) {
			w.velocities[i] = move_axis() * speed
		}
	}
}

ai_system :: proc(w: ^World, player: Entity, d: Dungeon) {
	// The enemy brain: wander until the player is inside aggro range,
	// chase until they get away (with slack, so the boundary doesn't
	// flip-flop), and do nothing while stunned. Sensing is room-scoped,
	// because aggro is a distance check and distance doesn't respect
	// walls: without the room test, enemies smell the player through
	// them, steer into the nearest wall, and slide along it into the
	// doorway, where they wait. Each room is its own arena.
	// Reads: Position, Ai, Health, the dungeon's rooms.
	// Writes: Velocity, Ai.
	if !alive(w, player) {
		return
	}
	target := w.positions[player.idx]
	player_room := room_at(d, target)
	for i in query(w, {.Ai, .Position, .Velocity}) {
		if has(w, i, .Health) && w.healths[i].stun > 0 {
			continue
		}
		same_room := room_at(d, w.positions[i]) == player_room
		to_player := target - w.positions[i]
		dist := linalg.length(to_player)
		switch w.ais[i].state {
		case .Wander:
			if same_room && dist < w.ais[i].aggro {
				w.ais[i].state = .Chase
			}
		case .Chase:
			if !same_room || dist > w.ais[i].aggro * 1.6 {
				w.ais[i].state = .Wander
				// Pick a fresh direction to drift off in.
				w.velocities[i] = {rand.float32_range(-60, 60),
				                   rand.float32_range(-60, 60)}
			}
		}
		if w.ais[i].state == .Chase && dist > 1 {
			w.velocities[i] = linalg.normalize(to_player) * w.ais[i].chase_speed
		}
	}
}

health_system :: proc(w: ^World, dt: f32) {
	// Ticks down the invulnerability and stun timers.
	// Reads: Health. Writes: Health.
	for i in query(w, {.Health}) {
		w.healths[i].invuln -= dt
		w.healths[i].stun -= dt
	}
}

damage_system :: proc(w: ^World) {
	// Applies every Contact_Damage -> Health contact from this frame:
	// subtract hp, grant i-frames, stun the victim and knock them away
	// from whatever hit them.
	// Reads: contacts, Collider, Contact_Damage. Writes: Health, Velocity.
	for c in w.contacts {
		if alive(w, c.a) && alive(w, c.b) &&
		   has(w, c.a.idx, .Contact_Damage) && has(w, c.b.idx, .Health) &&
		   w.healths[c.b.idx].invuln <= 0 {
			w.healths[c.b.idx].hp -= w.contact_damages[c.a.idx].amount
			w.healths[c.b.idx].invuln = w.healths[c.b.idx].invuln_time
			w.healths[c.b.idx].stun = 0.2
			if has(w, c.b.idx, .Velocity) {
				ar := collider_rect(w, c.a.idx)
				br := collider_rect(w, c.b.idx)
				dir := rl.Vector2{
					br.x + br.width / 2 - (ar.x + ar.width / 2),
					br.y + br.height / 2 - (ar.y + ar.height / 2),
				}
				// Dead-center overlaps have no direction; shove right.
				dir = linalg.normalize(dir) if linalg.length(dir) > 0 else {1, 0}
				w.velocities[c.b.idx] = dir * w.contact_damages[c.a.idx].knockback
			}
		}
	}
}

death_system :: proc(w: ^World) -> []rl.Vector2 {
	// Buries anything whose hp ran out, except the player (whose death
	// is the main file's problem). Returns where each one fell so the
	// caller can decorate the spot; systems stay GPU-free (Chapter 8's
	// lesson, applied at design time). The list lives on the temp
	// allocator and dies with the frame.
	// Reads: Health. Writes: entity liveness itself.
	dead := make([dynamic]Entity, context.temp_allocator)
	for i in query(w, {.Health}) {
		if w.healths[i].hp <= 0 && !has(w, i, .Player) {
			append(&dead, entity(w, i))
		}
	}
	fallen := make([dynamic]rl.Vector2, context.temp_allocator)
	for e in dead {
		append(&fallen, w.positions[e.idx])
		despawn(w, e)
	}
	return fallen[:]
}

movement_system :: proc(w: ^World, m: Tilemap, dt: f32,
                        noclip := false) {
	// Applies velocity to position. Entities with a collider move one
	// axis at a time and slide along solid tiles; .Bounce entities
	// also reflect their velocity off whatever axis hit. Anything
	// without a collider moves freely, and so does the player while
	// debug noclip is on.
	// Reads: Position, Velocity, Collider. Writes: Position, Velocity.
	for i in query(w, {.Position, .Velocity}) {
		delta := w.velocities[i] * dt
		if has(w, i, .Collider) && !(noclip && has(w, i, .Player)) {
			hit_x, hit_y := move_and_slide(m, &w.positions[i],
			                               w.colliders[i], delta)
			if has(w, i, .Bounce) {
				if hit_x do w.velocities[i].x = -w.velocities[i].x
				if hit_y do w.velocities[i].y = -w.velocities[i].y
			}
		} else {
			w.positions[i] += delta
		}
	}
}

contact_system :: proc(w: ^World) {
	// Finds every overlapping collider pair (A, B) where A cares about
	// B (B's layer is in A's hits set). Brute force over all collider
	// pairs: at room scale that is dozens of entities, and the whole
	// scan is cheaper than the bookkeeping any smarter structure needs.
	// Reads: Position, Collider. Writes: contacts (frame scratch).
	clear(&w.contacts)
	idx := query(w, {.Position, .Collider})
	for a in idx {
		if w.colliders[a].hits == {} do continue
		for b in idx {
			if a != b && w.colliders[b].layer in w.colliders[a].hits &&
			   rl.CheckCollisionRecs(collider_rect(w, a),
			                         collider_rect(w, b)) {
				append(&w.contacts, Contact{entity(w, a), entity(w, b)})
			}
		}
	}
}

pickup_system :: proc(w: ^World) -> []Pickup_Kind {
	// Despawns every pickup the player touched this frame and returns
	// what they were; the caller decides what a coin or a key means.
	// The list lives on the temp allocator and dies with the frame.
	// Reads: contacts, Collider, Pickup. Writes: entity liveness itself.
	got := make([dynamic]Entity, context.temp_allocator)
	for c in w.contacts {
		if alive(w, c.b) && w.colliders[c.b.idx].layer == .Pickup {
			append(&got, c.b)
		}
	}
	kinds := make([dynamic]Pickup_Kind, context.temp_allocator)
	for e in got {
		if alive(w, e) { // contacts can list a pickup twice
			append(&kinds, w.pickup_kinds[e.idx])
			despawn(w, e)
		}
	}
	return kinds[:]
}

actor_anim_system :: proc(w: ^World, atlas: ^Atlas) {
	// Faces sprites along their horizontal motion and switches between
	// idle and run animations. Standing still keeps the last facing.
	// Runs after movement, so a bounced critter faces its new direction.
	// Reads: Velocity, Actor. Writes: Sprite.
	for i in query(w, {.Velocity, .Actor, .Sprite}) {
		v := w.velocities[i]
		if v.x < 0 {
			w.sprites[i].flip_x = true
		} else if v.x > 0 {
			w.sprites[i].flip_x = false
		}
		anim := w.actors[i].idle_anim
		if linalg.length(v) > 1 {
			anim = w.actors[i].run_anim
		}
		set_anim(&w.sprites[i], atlas, anim)
	}
}

animation_system :: proc(w: ^World, dt: f32) {
	// Advances every animation clock (Chapter 3's update behind a query).
	// Reads: Sprite. Writes: Sprite.
	for i in query(w, {.Sprite}) {
		sprite_update(&w.sprites[i], dt)
	}
}

lifetime_system :: proc(w: ^World, dt: f32) {
	// Counts lifetimes down; despawns what expires. Despawning edits
	// the mask array, so never do it while walking a query you also
	// mutate: collect the dead first, bury after.
	// Reads: Lifetime. Writes: Lifetime, entity liveness itself.
	dead := make([dynamic]Entity, context.temp_allocator)
	for i in query(w, {.Lifetime}) {
		w.lifetimes[i] -= dt
		if w.lifetimes[i] <= 0 {
			append(&dead, entity(w, i))
		}
	}
	for e in dead {
		despawn(w, e)
	}
}

Draw_Layer :: enum {
	// Back-to-front draw order: death decals under dropped loot under
	// the living.
	Decal,
	Loot,
	Actor,
}

sprite_layer :: proc(w: ^World, i: i32) -> Draw_Layer {
	// What an entity is decides where it draws: the living — and the
	// sword they swing — on top, loot beneath them, and anything else
	// (the skull decals) on the floor where it belongs.
	if has(w, i, .Actor) || has(w, i, .Contact_Damage) do return .Actor
	if has(w, i, .Pickup) do return .Loot
	return .Decal
}

draw_system :: proc(w: ^World, atlas: ^Atlas) {
	// Draws every entity that has a position and a sprite, one layer
	// at a time (slot order within a layer).
	// Reads: Position, Sprite. Writes: nothing (only the screen).
	for layer in Draw_Layer {
		for i in query(w, {.Position, .Sprite}) {
			if sprite_layer(w, i) != layer do continue
			sprite_draw(w.sprites[i], atlas, w.positions[i])
		}
	}
}
