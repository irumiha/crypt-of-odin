// The floor generator: an Isaac-style grid of screen-sized rooms.
//
// A seeded random walk picks which grid cells become rooms, every
// pair of adjacent rooms gets a doorway, the farthest room gets the
// stairs down (sealed), and the key to the seal goes in the farthest
// ordinary room. Everything is carved into a plain Tilemap, so all of
// chapters 6-9 keeps working untouched, and the whole file runs
// headless (the tests lean on that).
//
// Determinism is the point of taking a seed: the same seed always
// builds the same floor, which makes bugs reproducible and daily
// challenge runs possible. Chapter 2 promised this payoff.

package crypt

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

ROOM_COLS :: 4 // the floor is a 4x3 grid of potential rooms
ROOM_ROWS :: 3
ROOM_W :: 25 // tiles per room: exactly one 800x450 screen
ROOM_H :: 14

Room :: struct {
	gx, gy: i32, // which grid cell this room occupies
	depth:  i32, // steps from the start room, filled by BFS
}

Dungeon :: struct {
	tilemap:     Tilemap,
	rooms:       [dynamic]Room,
	start_room:  int,
	key_room:    int, // holds the seal-dissolving flask
	stairs_room: int, // holds the stairs down, behind sealed doors
	sealed:      [dynamic][2]i32,
}

destroy_dungeon :: proc(d: ^Dungeon) {
	destroy_tilemap(&d.tilemap)
	delete(d.rooms)
	delete(d.sealed)
}

room_index_at :: proc(d: Dungeon, gx, gy: i32) -> int {
	// The room occupying a grid cell, or -1.
	for r, i in d.rooms {
		if r.gx == gx && r.gy == gy {
			return i
		}
	}
	return -1
}

carve_room :: proc(m: ^Tilemap, room: Room) {
	// One cell: walls on the perimeter, floor inside.
	ox := room.gx * ROOM_W
	oy := room.gy * ROOM_H
	for y in i32(0) ..< ROOM_H {
		for x in i32(0) ..< ROOM_W {
			border := x == 0 || y == 0 || x == ROOM_W - 1 || y == ROOM_H - 1
			set_tile(m, ox + x, oy + y, .Wall if border else .Floor)
		}
	}
}

carve_door :: proc(d: ^Dungeon, a, b: Room, seal: bool) {
	// A 2-tile-wide opening through the double wall between two
	// adjacent rooms; sealed doors get .Sealed instead of floor and
	// are remembered so unlock can dissolve them.
	spots := make([dynamic][2]i32, context.temp_allocator)
	if a.gy == b.gy { // side by side: carve through 2 columns
		left := min(a.gx, b.gx)
		cols := [2]i32{left * ROOM_W + ROOM_W - 1, left * ROOM_W + ROOM_W}
		mid_y := a.gy * ROOM_H + ROOM_H / 2
		for c in cols {
			append(&spots, [2]i32{c, mid_y - 1})
			append(&spots, [2]i32{c, mid_y})
		}
	} else { // stacked: carve through 2 rows
		top := min(a.gy, b.gy)
		rows := [2]i32{top * ROOM_H + ROOM_H - 1, top * ROOM_H + ROOM_H}
		mid_x := a.gx * ROOM_W + ROOM_W / 2
		for r in rows {
			append(&spots, [2]i32{mid_x - 1, r})
			append(&spots, [2]i32{mid_x, r})
		}
	}
	for s in spots {
		set_tile(&d.tilemap, s.x, s.y, .Sealed if seal else .Floor)
		if seal {
			append(&d.sealed, s)
		}
	}
}

generate :: proc(seed: i64, floor_num: int) -> (d: Dungeon) {
	// Builds a whole floor from a seed. Same seed, same floor, every
	// time, on every machine: the generator gets its own random state
	// instead of the global one precisely so nothing else can disturb
	// it.
	state := rand.create(u64(seed))
	rng := rand.default_random_generator(&state)
	target_rooms := min(6 + floor_num, ROOM_COLS * ROOM_ROWS)

	// A random walk from the center claims grid cells.
	append(&d.rooms, Room{gx = ROOM_COLS / 2, gy = ROOM_ROWS / 2})
	for len(d.rooms) < target_rooms {
		origin := d.rooms[rand.int_max(len(d.rooms), rng)]
		dirs := [4][2]i32{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
		dir := dirs[rand.int_max(4, rng)]
		nx := origin.gx + dir.x
		ny := origin.gy + dir.y
		if nx >= 0 && ny >= 0 && nx < ROOM_COLS && ny < ROOM_ROWS &&
		   room_index_at(d, nx, ny) < 0 {
			append(&d.rooms, Room{gx = nx, gy = ny})
		}
	}

	d.tilemap = init_tilemap(ROOM_COLS * ROOM_W, ROOM_ROWS * ROOM_H)
	for room in d.rooms {
		carve_room(&d.tilemap, room)
	}

	// BFS depths from the start room, over grid adjacency.
	d.start_room = 0
	queue := make([dynamic]int, context.temp_allocator)
	seen := make([]bool, len(d.rooms), context.temp_allocator)
	append(&queue, 0)
	seen[0] = true
	for head := 0; head < len(queue); head += 1 {
		cur := queue[head]
		dirs := [4][2]i32{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
		for dir in dirs {
			n := room_index_at(d, d.rooms[cur].gx + dir.x,
			                   d.rooms[cur].gy + dir.y)
			if n >= 0 && !seen[n] {
				seen[n] = true
				d.rooms[n].depth = d.rooms[cur].depth + 1
				append(&queue, n)
			}
		}
	}

	// The stairs hide in the deepest room; the key in the deepest room
	// that is neither the stairs nor the entrance.
	d.stairs_room = 0
	for r, i in d.rooms {
		if r.depth > d.rooms[d.stairs_room].depth {
			d.stairs_room = i
		}
	}
	d.key_room = -1
	for r, i in d.rooms {
		if i != d.stairs_room && i != d.start_room &&
		   (d.key_room < 0 || r.depth > d.rooms[d.key_room].depth) {
			d.key_room = i
		}
	}
	if d.key_room < 0 { // two-room floor: key sits at the start
		d.key_room = d.start_room
	}

	// Doorways between every pair of adjacent rooms; the stairs room's
	// doors are sealed until the key dissolves them.
	for a, i in d.rooms {
		for b, j in d.rooms {
			if j > i && abs(a.gx - b.gx) + abs(a.gy - b.gy) == 1 {
				seal := i == d.stairs_room || j == d.stairs_room
				carve_door(&d, a, b, seal)
			}
		}
	}

	// The stairs themselves, center of their room.
	sr := d.rooms[d.stairs_room]
	set_tile(&d.tilemap, sr.gx * ROOM_W + ROOM_W / 2,
	         sr.gy * ROOM_H + ROOM_H / 2, .Stairs)
	return
}

unlock :: proc(d: ^Dungeon) {
	// The key dissolves every sealed tile into ordinary floor.
	for s in d.sealed {
		set_tile(&d.tilemap, s.x, s.y, .Floor)
	}
	clear(&d.sealed)
}

is_locked :: proc(d: Dungeon) -> bool {
	return len(d.sealed) > 0
}

room_center :: proc(d: Dungeon, room: int) -> rl.Vector2 {
	// The world-space center of a room (what the camera looks at).
	return {
		f32(d.rooms[room].gx * ROOM_W * TILE_SIZE) + ROOM_W * TILE_SIZE / 2,
		f32(d.rooms[room].gy * ROOM_H * TILE_SIZE) + ROOM_H * TILE_SIZE / 2,
	}
}

room_at :: proc(d: Dungeon, pos: rl.Vector2) -> int {
	// Which room a world position is in, or -1 for the void between.
	// Floor division, same reason as collision's tile_coord: truncation
	// would fold the strip just left of (or above) the map into grid
	// cell zero and claim there is a room there.
	gx := i32(math.floor(pos.x / (ROOM_W * TILE_SIZE)))
	gy := i32(math.floor(pos.y / (ROOM_H * TILE_SIZE)))
	return room_index_at(d, gx, gy)
}

random_pos_in :: proc(d: Dungeon, room: int) -> rl.Vector2 {
	// A spot on a random interior tile of a room (for spawning): tile
	// offsets 2 through ROOM_W - 3 / ROOM_H - 3, a two-tile margin from
	// the walls on every side (int31_max's bound is exclusive).
	r := d.rooms[room]
	x := r.gx * ROOM_W + 2 + rand.int31_max(ROOM_W - 4)
	y := r.gy * ROOM_H + 2 + rand.int31_max(ROOM_H - 4)
	return {f32(x * TILE_SIZE), f32(y * TILE_SIZE)}
}
