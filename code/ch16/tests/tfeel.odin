// Headless tests for the feel systems: particles are arithmetic over
// parallel arrays, shake is one decaying number, and both have
// invariants worth pinning.

package tests

import "core:math/linalg"
import "core:testing"
import crypt "../src"

@(test)
a_burst_adds_exactly_count_particles :: proc(t: ^testing.T) {
	p: crypt.Particles
	defer crypt.destroy_particles(&p)
	crypt.emit_burst(&p, {0, 0}, 25, {230, 41, 55, 255}, speed = 100)
	testing.expect_value(t, crypt.particles_len(p), 25)
}

@(test)
expiry_compacts_every_parallel_array_in_lockstep :: proc(t: ^testing.T) {
	p: crypt.Particles
	defer crypt.destroy_particles(&p)
	crypt.emit_burst(&p, {0, 0}, 40, {230, 41, 55, 255}, speed = 100,
	                 life_secs = 0.2)
	// Max life is 0.2, min is 0.1 (the 0.5..1.0 spread), so:
	crypt.particles_update(&p, 0.05)
	testing.expect_value(t, crypt.particles_len(p), 40) // too early for anyone
	crypt.particles_update(&p, 0.30)
	testing.expect_value(t, crypt.particles_len(p), 0) // too late for everyone
	crypt.emit_burst(&p, {0, 0}, 10, {230, 41, 55, 255}, speed = 100)
	testing.expect_value(t, crypt.particles_len(p), 10) // still usable
}

@(test)
drag_slows_debris_down :: proc(t: ^testing.T) {
	p: crypt.Particles
	defer crypt.destroy_particles(&p)
	crypt.emit_burst(&p, {0, 0}, 1, {230, 41, 55, 255}, speed = 100,
	                 life_secs = 5)
	before := linalg.length(crypt.particle_body(p, 0).vel)
	crypt.particles_update(&p, 0.1)
	testing.expect(t, linalg.length(crypt.particle_body(p, 0).vel) < before)
}

@(test)
trauma_accumulates_clamps_at_one_and_decays_to_zero :: proc(t: ^testing.T) {
	s: crypt.Shake
	crypt.add_trauma(&s, 0.7)
	crypt.add_trauma(&s, 0.7)
	testing.expect_value(t, s.trauma, f32(1))
	crypt.shake_update(&s, 0.5)
	testing.expect(t, abs(s.trauma - 0.25) < 0.001)
	crypt.shake_update(&s, 10)
	testing.expect_value(t, s.trauma, f32(0))
}

@(test)
displacement_is_bounded_by_trauma_squared :: proc(t: ^testing.T) {
	s: crypt.Shake
	crypt.add_trauma(&s, 0.5) // trauma^2 = 0.25, max 6 px -> 1.5
	for _ in 0 ..< 100 {
		o := crypt.shake_offset(s)
		testing.expect(t, abs(o.x) <= 1.5)
		testing.expect(t, abs(o.y) <= 1.5)
	}
}
