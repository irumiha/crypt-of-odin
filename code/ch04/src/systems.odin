// Systems: procs that each run one query and do one job. The frame
// loop calls them in a fixed order; that list (in main.odin) is the
// entire control flow of the game — no system calls another.
//
// Data flows between systems implicitly (one writes state, a later one
// reads it), which is why every system below declares what it reads
// and writes. Keep those lines accurate when editing.

package crypt

import rl "vendor:raylib"

movement_system :: proc(w: ^World, dt: f32) {
	// Applies velocity to position. Entities without a Velocity (the
	// knight, coins) are skipped by the query itself.
	// Reads: Position, Velocity. Writes: Position.
	for i in query(w, {.Position, .Velocity}) {
		w.positions[i] += w.velocities[i] * dt
	}
}

bounce_system :: proc(w: ^World, bounds: rl.Vector2) {
	// Reflects anything that runs into the screen edge, using the
	// sprite's on-screen size for the far edges. Runs after movement,
	// so it sees this frame's final positions.
	// Reads: Position, Sprite. Writes: Velocity.
	for i in query(w, {.Position, .Velocity, .Sprite}) {
		size := rl.Vector2{sprite_width(w.sprites[i]),
		                   sprite_height(w.sprites[i])}
		if w.positions[i].x < 0 || w.positions[i].x + size.x > bounds.x {
			w.velocities[i].x = -w.velocities[i].x
		}
		if w.positions[i].y < 0 || w.positions[i].y + size.y > bounds.y {
			w.velocities[i].y = -w.velocities[i].y
		}
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
