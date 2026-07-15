// The particle system: the one subsystem in this game where data
// layout earns its keep, and the reason it is deliberately NOT part
// of the ECS. Particles arrive in the thousands, are updated by one
// narrow loop touching two or three fields, and never interact with
// anything, so entity identity, masks, and queries would be pure
// overhead. Plain parallel arrays (structure of arrays) it is.
//
// One rule inherited from Chapter 4's research: position and velocity
// stay together in one struct. Splitting a Vector2 into separate x/y
// arrays doubles the memory streams and defeats vectorization.

package crypt

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

Particle_Body :: struct {
	pos, vel: rl.Vector2,
}

Particles :: struct {
	// Parallel arrays, one entry per particle, always in lockstep:
	// index i means the same particle in every array.
	bodies:   [dynamic]Particle_Body,
	life:     [dynamic]f32,
	max_life: [dynamic]f32,
	colors:   [dynamic]rl.Color,
}

particles_len :: proc(p: Particles) -> int {
	return len(p.bodies)
}

particle_body :: proc(p: Particles, i: int) -> Particle_Body {
	// Read access for inspection (tests, debug overlays).
	return p.bodies[i]
}

destroy_particles :: proc(p: ^Particles) {
	delete(p.bodies)
	delete(p.life)
	delete(p.max_life)
	delete(p.colors)
}

emit_burst :: proc(p: ^Particles, pos: rl.Vector2, count: int,
                   color: rl.Color, speed: f32, life_secs: f32 = 0.5) {
	// A radial puff: count particles in random directions, randomized
	// speed and lifespan so the burst reads as debris, not a firework.
	for _ in 0 ..< count {
		ang := rand.float32_range(0, 2 * math.PI)
		spd := speed * (0.4 + rand.float32_range(0, 0.6))
		append(&p.bodies, Particle_Body{
			pos = pos,
			vel = {math.cos(ang) * spd, math.sin(ang) * spd},
		})
		life := life_secs * (0.5 + rand.float32_range(0, 0.5))
		append(&p.life, life)
		append(&p.max_life, life)
		append(&p.colors, color)
	}
}

particles_update :: proc(p: ^Particles, dt: f32) {
	// Two passes. First the hot loop: move and drag, touching only the
	// bodies array, front to back, exactly the shape CPUs love. Then
	// bookkeeping: expire and compact, swap-and-pop across every array
	// in lockstep, which is the tax SoA charges for its speed.
	for &b in p.bodies {
		b.pos += b.vel * dt
		b.vel *= 1 - 4 * dt // drag; debris settles fast
	}
	for i := 0; i < len(p.life); {
		p.life[i] -= dt
		if p.life[i] <= 0 {
			unordered_remove(&p.bodies, i)
			unordered_remove(&p.life, i)
			unordered_remove(&p.max_life, i)
			unordered_remove(&p.colors, i)
		} else {
			i += 1
		}
	}
}

particles_draw :: proc(p: Particles) {
	// Small squares, fading with remaining life. Call inside the
	// camera block; particles live in world space.
	for i in 0 ..< len(p.bodies) {
		c := p.colors[i]
		c.a = u8(255 * clamp(p.life[i] / p.max_life[i], 0, 1))
		rl.DrawRectangle(i32(p.bodies[i].pos.x), i32(p.bodies[i].pos.y),
		                 3, 3, c)
	}
}
