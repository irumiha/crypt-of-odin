// Systems: procs that each run one query and do one job. The frame
// loop calls them in a fixed order; that list (in main.odin) is the
// entire control flow of the game — no system calls another.
//
// Data flows between systems implicitly (one writes state, a later one
// reads it), which is why every system below declares what it reads
// and writes. Keep those lines accurate when editing.

package crypt

import "core:math/linalg"
import rl "vendor:raylib"

player_input_system :: proc(w: ^World, speed: f32) {
	// Turns the player's held keys into velocity, overwriting whatever
	// was there: the player moves exactly as told, every frame.
	// Reads: the keyboard (via the action map). Writes: Velocity.
	for i in query(w, {.Player, .Velocity}) {
		w.velocities[i] = move_axis() * speed
	}
}

movement_system :: proc(w: ^World, m: Tilemap, dt: f32) {
	// Applies velocity to position. Entities with a collider move one
	// axis at a time and slide along solid tiles; .Bounce entities
	// also reflect their velocity off whatever axis hit. Anything
	// without a collider moves freely.
	// Reads: Position, Velocity, Collider. Writes: Position, Velocity.
	for i in query(w, {.Position, .Velocity}) {
		delta := w.velocities[i] * dt
		if has(w, i, .Collider) {
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

pickup_system :: proc(w: ^World) -> (collected: int) {
	// Despawns every pickup the player touched this frame and returns
	// how many (the caller keeps the score). Contacts are already
	// layer-filtered; only the player has .Pickup in its hits.
	// Reads: contacts, Collider. Writes: entity liveness itself.
	got := make([dynamic]Entity, context.temp_allocator)
	for c in w.contacts {
		if alive(w, c.b) && w.colliders[c.b.idx].layer == .Pickup {
			append(&got, c.b)
		}
	}
	for e in got {
		despawn(w, e)
		collected += 1
	}
	return
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

draw_system :: proc(w: ^World, atlas: ^Atlas) {
	// Draws every entity that has a position and a sprite, in slot
	// order (draw-order control comes with later chapters).
	// Reads: Position, Sprite. Writes: nothing (only the screen).
	for i in query(w, {.Position, .Sprite}) {
		sprite_draw(w.sprites[i], atlas, w.positions[i])
	}
}
