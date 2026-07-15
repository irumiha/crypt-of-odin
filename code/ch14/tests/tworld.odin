// Headless tests for the game world: the real systems, the real
// collision code, no window and no GPU. Run with `odin test tests`
// from the chapter directory.
//
// What gets tested here is invariants (positions, liveness, counts),
// not feel. Feel stays in the playtester's hands, where it belongs.

package tests

import "core:testing"
import crypt "../src"

TINY_MAP :: `########
#......#
#......#
########`
// 8x4 tiles: floor spans x 32..223, y 32..95 in world pixels.

spawn_box :: proc(w: ^crypt.World, x, y: f32, vx: f32 = 0, vy: f32 = 0,
                  extra: crypt.Comp_Set = {}) -> crypt.Entity {
	// A 32x32 test entity; no sprite, because nothing here draws.
	e := crypt.spawn(w, {.Position, .Velocity, .Collider} + extra)
	w.positions[e.idx] = {x, y}
	w.velocities[e.idx] = {vx, vy}
	w.colliders[e.idx] = {size = {32, 32}}
	return e
}

@(test)
driving_right_stops_flush_against_the_wall :: proc(t: ^testing.T) {
	// The Chapter 7 autopilot, promoted to a regression test.
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	tiles := crypt.parse_map(TINY_MAP)
	defer crypt.destroy_tilemap(&tiles)
	e := spawn_box(&world, x = 66, y = 40, vx = 200)
	for _ in 0 ..< 120 {
		crypt.movement_system(&world, tiles, 1.0 / 60)
	}
	testing.expect_value(t, world.positions[e.idx].x,
	                     f32(7 * crypt.TILE_SIZE) - 32)
	testing.expect_value(t, world.positions[e.idx].y, f32(40))
}

@(test)
diagonal_movement_slides_along_the_wall_then_corners :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	tiles := crypt.parse_map(TINY_MAP)
	defer crypt.destroy_tilemap(&tiles)
	e := spawn_box(&world, x = 66, y = 40, vx = 200, vy = 50)
	for _ in 0 ..< 120 {
		crypt.movement_system(&world, tiles, 1.0 / 60)
	}
	// Pinned in the bottom-right inner corner, flush on both axes.
	testing.expect_value(t, world.positions[e.idx].x,
	                     f32(7 * crypt.TILE_SIZE) - 32)
	testing.expect_value(t, world.positions[e.idx].y,
	                     f32(3 * crypt.TILE_SIZE) - 32)
}

@(test)
the_bounce_tag_reflects_velocity_off_a_wall :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	tiles := crypt.parse_map(TINY_MAP)
	defer crypt.destroy_tilemap(&tiles)
	e := spawn_box(&world, x = 180, y = 40, vx = 400, extra = {.Bounce})
	for _ in 0 ..< 10 {
		crypt.movement_system(&world, tiles, 1.0 / 60)
	}
	testing.expect_value(t, world.velocities[e.idx].x, f32(-400))
	testing.expect(t, world.positions[e.idx].x < f32(7 * crypt.TILE_SIZE) - 32)
}

@(test)
the_void_left_of_the_map_is_solid :: proc(t: ^testing.T) {
	// Pins collision's floor division: truncating division would fold
	// world x in (-32, 0) into tile column 0, so on a map whose column
	// 0 is floor, a box hanging into negative space would read as
	// safely on the floor instead of inside the solid void.
	tiles := crypt.parse_map("....\n....")
	defer crypt.destroy_tilemap(&tiles)
	testing.expect(t, crypt.overlaps_solid(tiles, {-16, 8, 8, 8}))
	testing.expect(t, crypt.overlaps_solid(tiles, {8, -16, 8, 8}))
	testing.expect(t, !crypt.overlaps_solid(tiles, {8, 8, 8, 8}))
}

@(test)
the_player_picks_up_an_overlapping_coin_only_once :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	player := spawn_box(&world, x = 100, y = 100)
	world.colliders[player.idx].layer = .Player
	world.colliders[player.idx].hits = {.Pickup}
	coin := spawn_box(&world, x = 110, y = 110, extra = {.Pickup})
	world.colliders[coin.idx].layer = .Pickup
	world.pickup_kinds[coin.idx] = .Coin
	bystander := spawn_box(&world, x = 112, y = 112)
	world.colliders[bystander.idx].layer = .Enemy

	crypt.contact_system(&world)
	got := crypt.pickup_system(&world)
	testing.expect_value(t, len(got), 1)
	testing.expect_value(t, got[0], crypt.Pickup_Kind.Coin)
	testing.expect(t, !crypt.alive(&world, coin))
	testing.expect(t, crypt.alive(&world, bystander)) // enemies are not currency
}

@(test)
a_stale_handle_reads_dead_after_its_slot_is_reused :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	first := crypt.spawn(&world, {.Position})
	crypt.despawn(&world, first)
	second := crypt.spawn(&world, {.Position})
	testing.expect_value(t, second.idx, first.idx) // the slot was recycled...
	testing.expect(t, !crypt.alive(&world, first)) // ...and the old handle knows
	testing.expect(t, crypt.alive(&world, second))
	testing.expect_value(t, crypt.entity_count(&world), 1)
}
