// Headless tests for the floor generator: connectivity, determinism,
// and the lock-and-key contract. Generators are the most testable
// code in a game, and the easiest to break with an innocent tweak.

package tests

import "core:testing"
import crypt "../src"

tiles_equal :: proc(a, b: crypt.Tilemap) -> bool {
	if a.width != b.width || a.height != b.height {
		return false
	}
	for y in i32(0) ..< a.height {
		for x in i32(0) ..< a.width {
			if crypt.tile_at(a, x, y) != crypt.tile_at(b, x, y) {
				return false
			}
		}
	}
	return true
}

count_tiles :: proc(m: crypt.Tilemap, kind: crypt.Tile_Kind) -> (n: int) {
	for y in i32(0) ..< m.height {
		for x in i32(0) ..< m.width {
			if crypt.tile_at(m, x, y) == kind {
				n += 1
			}
		}
	}
	return
}

@(test)
the_same_seed_builds_the_same_floor_twice :: proc(t: ^testing.T) {
	a := crypt.generate(42, 1)
	defer crypt.destroy_dungeon(&a)
	b := crypt.generate(42, 1)
	defer crypt.destroy_dungeon(&b)
	testing.expect(t, tiles_equal(a.tilemap, b.tilemap))
}

@(test)
different_seeds_build_different_floors :: proc(t: ^testing.T) {
	a := crypt.generate(42, 1)
	defer crypt.destroy_dungeon(&a)
	b := crypt.generate(43, 1)
	defer crypt.destroy_dungeon(&b)
	testing.expect(t, !tiles_equal(a.tilemap, b.tilemap))
}

@(test)
every_room_is_reachable_from_the_start :: proc(t: ^testing.T) {
	// BFS depth 0 is only correct for the start room; everything else
	// reachable got a positive depth during generation's own BFS.
	for seed in 1 ..= 20 {
		d := crypt.generate(i64(seed), 2)
		defer crypt.destroy_dungeon(&d)
		for room, i in d.rooms {
			if i != d.start_room {
				testing.expect(t, room.depth > 0)
			}
		}
	}
}

@(test)
special_rooms_are_distinct_when_the_floor_is_big_enough :: proc(t: ^testing.T) {
	for seed in 1 ..= 20 {
		d := crypt.generate(i64(seed), 2) // floor 2: eight rooms
		defer crypt.destroy_dungeon(&d)
		testing.expect(t, d.stairs_room != d.start_room)
		testing.expect(t, d.key_room != d.stairs_room)
		testing.expect(t, d.key_room != d.start_room)
	}
}

@(test)
room_lookup_inverts_room_centers :: proc(t: ^testing.T) {
	d := crypt.generate(7, 1)
	defer crypt.destroy_dungeon(&d)
	for i in 0 ..< len(d.rooms) {
		testing.expect_value(t, crypt.room_at(d, crypt.room_center(d, i)), i)
	}
}

@(test)
stairs_start_sealed_and_the_key_dissolves_exactly_the_seals :: proc(
	t: ^testing.T,
) {
	d := crypt.generate(99, 1)
	defer crypt.destroy_dungeon(&d)
	testing.expect(t, crypt.is_locked(d))
	seals := count_tiles(d.tilemap, .Sealed)
	testing.expect(t, seals > 0)
	floors := count_tiles(d.tilemap, .Floor)
	crypt.unlock(&d)
	testing.expect(t, !crypt.is_locked(d))
	testing.expect_value(t, count_tiles(d.tilemap, .Sealed), 0)
	testing.expect_value(t, count_tiles(d.tilemap, .Floor), floors + seals)
}

@(test)
there_is_exactly_one_staircase :: proc(t: ^testing.T) {
	for seed in 1 ..= 20 {
		d := crypt.generate(i64(seed), 3)
		defer crypt.destroy_dungeon(&d)
		testing.expect_value(t, count_tiles(d.tilemap, .Stairs), 1)
	}
}
