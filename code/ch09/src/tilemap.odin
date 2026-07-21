// The crypt as data: a grid of tile kinds parsed from ASCII art. Your
// text editor is the level editor; a `#` is a wall, a `.` is floor,
// anything else is the void outside.
//
// Changed in Chapter 8: the map no longer touches the atlas. Pure
// world data lives here (usable in headless tests, no GPU required);
// how it looks lives in Tile_Skin, built from the atlas by whoever
// actually intends to draw.

package crypt

import "core:fmt"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

SCALE :: 2 // 16px art, 32px on screen (the map owns the pixel math now)
TILE_SIZE :: 16 * SCALE

// Tint multiplies the texture's colors; a gray-purple darkens the
// brick into a believable wall top without extra art.
WALL_TOP_TINT :: rl.Color{110, 100, 130, 255}

Tile_Kind :: enum {
	Void, Floor, Wall,
}

FLOOR_VARIANTS :: 4

Tilemap :: struct {
	width, height:  i32, // in tiles
	tiles:          [dynamic]Tile_Kind, // row-major, width*height entries
	floor_variants: [dynamic]i32, // 1..FLOOR_VARIANTS, rolled once per cell
}

Tile_Skin :: struct {
	// The map's looks: which atlas regions the tile kinds draw with.
	// Kept apart from Tilemap so the world data stays GPU-free.
	floors: [FLOOR_VARIANTS + 1]rl.Rectangle, // 1..FLOOR_VARIANTS used; slot 0 sits empty
	wall:   rl.Rectangle,
}

roll_floor_variant :: proc() -> i32 {
	// Weighted toward the plain tile so cracks read as wear.
	return 1 if rand.float32() < 0.9 else 2 + rand.int31_max(FLOOR_VARIANTS - 1)
}

parse_map :: proc(ascii: string) -> (m: Tilemap) {
	// Builds a map from ASCII art. Lines may have ragged lengths; the
	// map is as wide as the longest one and short lines pad with void.
	lines := strings.split_lines(strings.trim(ascii, "\n"),
	                             context.temp_allocator)
	m.height = i32(len(lines))
	for line in lines {
		m.width = max(m.width, i32(len(line)))
	}
	for y in 0 ..< m.height {
		for x in 0 ..< m.width {
			ch: u8 = ' '
			if int(x) < len(lines[y]) {
				ch = lines[y][x]
			}
			kind: Tile_Kind
			switch ch {
			case '#': kind = .Wall
			case '.': kind = .Floor
			case:     kind = .Void
			}
			append(&m.tiles, kind)
			append(&m.floor_variants, roll_floor_variant())
		}
	}
	return
}

destroy_tilemap :: proc(m: ^Tilemap) {
	delete(m.tiles)
	delete(m.floor_variants)
}

make_skin :: proc(atlas: ^Atlas) -> (skin: Tile_Skin) {
	// Resolves the tile art once, at load time.
	for i in 1 ..= FLOOR_VARIANTS {
		skin.floors[i] = atlas_rect(atlas, fmt.tprintf("floor_%d", i))
	}
	skin.wall = atlas_rect(atlas, "wall_mid")
	return
}

tile_at :: proc(m: Tilemap, x, y: i32) -> Tile_Kind {
	// The tile at a grid coordinate; everything outside the map is
	// void. (The collision checks lean on that.)
	if x < 0 || y < 0 || x >= m.width || y >= m.height {
		return .Void
	}
	return m.tiles[y * m.width + x]
}

pixel_size :: proc(m: Tilemap) -> rl.Vector2 {
	// The map's size in world pixels (for camera clamping and bounds).
	return {f32(m.width * TILE_SIZE), f32(m.height * TILE_SIZE)}
}

random_floor_pos :: proc(m: Tilemap) -> rl.Vector2 {
	// The top-left corner of a random floor tile, for spawning things
	// somewhere sensible. Loops until it hits floor, which on any sane
	// map takes a couple of tries.
	for {
		x := rand.int31_max(m.width)
		y := rand.int31_max(m.height)
		if tile_at(m, x, y) == .Floor {
			return {f32(x * TILE_SIZE), f32(y * TILE_SIZE)}
		}
	}
}

tilemap_draw :: proc(m: Tilemap, atlas: ^Atlas, skin: Tile_Skin) {
	// Draws the whole map in world coordinates; the camera decides
	// what's on screen. Void cells stay undrawn (the background shows).
	for y in 0 ..< m.height {
		for x in 0 ..< m.width {
			i := y * m.width + x
			dest := rl.Rectangle{f32(x * TILE_SIZE), f32(y * TILE_SIZE),
			                     TILE_SIZE, TILE_SIZE}
			switch m.tiles[i] {
			case .Floor:
				rl.DrawTexturePro(atlas.texture,
				                  skin.floors[m.floor_variants[i]],
				                  dest, {0, 0}, 0, rl.WHITE)
			case .Wall:
				// A wall cell with floor directly below it is a front
				// face and draws at full brightness; every other wall
				// cell is a "top" and draws darkened via the tint.
				tint := rl.WHITE if tile_at(m, x, y + 1) == .Floor else WALL_TOP_TINT
				rl.DrawTexturePro(atlas.texture, skin.wall, dest,
				                  {0, 0}, 0, tint)
			case .Void:
			}
		}
	}
}
