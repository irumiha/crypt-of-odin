// The crypt as data: a grid of tile kinds parsed from ASCII art and
// drawn from the atlas. Your text editor is the level editor; a `#`
// is a wall, a `.` is floor, anything else is the void outside.
//
// Chapter 10 replaces the hand-drawn map with a generator, but it
// produces this same Tilemap, so everything downstream survives.

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

Tilemap :: struct {
	width, height: i32, // in tiles
	tiles:         [dynamic]Tile_Kind, // row-major, width*height entries
	floor_rects:   [dynamic]rl.Rectangle, // pre-rolled floor variant per cell
	wall_rect:     rl.Rectangle,
}

parse_map :: proc(atlas: ^Atlas, ascii: string) -> (m: Tilemap) {
	// Builds a map from ASCII art. Lines may have ragged lengths; the
	// map is as wide as the longest one and short lines pad with void.
	// Floor variants are rolled here, once, per cell (Chapter 3's
	// roll-at-startup rule, now living inside the map).
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
			name := "floor_1"
			if rand.float32() >= 0.9 {
				name = fmt.tprintf("floor_%d", 2 + rand.int_max(7))
			}
			append(&m.floor_rects, atlas_rect(atlas, name))
		}
	}
	m.wall_rect = atlas_rect(atlas, "wall_mid")
	return
}

destroy_tilemap :: proc(m: ^Tilemap) {
	delete(m.tiles)
	delete(m.floor_rects)
}

tile_at :: proc(m: Tilemap, x, y: i32) -> Tile_Kind {
	// The tile at a grid coordinate; everything outside the map is
	// void. (Chapter 7's collision checks lean on that.)
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

tilemap_draw :: proc(m: Tilemap, atlas: ^Atlas) {
	// Draws the whole map in world coordinates; the camera decides
	// what's on screen. Void cells stay undrawn (the background shows).
	for y in i32(0) ..< m.height {
		for x in i32(0) ..< m.width {
			i := y * m.width + x
			dest := rl.Rectangle{f32(x * TILE_SIZE), f32(y * TILE_SIZE),
			                     TILE_SIZE, TILE_SIZE}
			switch m.tiles[i] {
			case .Floor:
				rl.DrawTexturePro(atlas.texture, m.floor_rects[i], dest,
				                  {0, 0}, 0, rl.WHITE)
			case .Wall:
				// A wall cell with floor directly below it is a front
				// face and draws at full brightness; every other wall
				// cell is a "top" and draws darkened via the tint
				// parameter. Two draw calls' worth of logic instead of
				// a full autotiling set, and the rooms still read.
				tint := rl.WHITE if tile_at(m, x, y + 1) == .Floor else WALL_TOP_TINT
				rl.DrawTexturePro(atlas.texture, m.wall_rect, dest,
				                  {0, 0}, 0, tint)
			case .Void:
			}
		}
	}
}
