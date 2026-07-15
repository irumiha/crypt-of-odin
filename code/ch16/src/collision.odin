// Collision with the world's masonry: solid-tile overlap tests and
// axis-separated move-and-slide.
//
// The tilemap needs no spatial index because it is one: which tiles a
// box overlaps is integer division, and each check touches only the
// handful of cells under the box.

package crypt

import "core:math"
import rl "vendor:raylib"

SOLID_TILES :: bit_set[Tile_Kind]{.Wall, .Void, .Sealed}
// Void is solid on purpose: nothing walks off the edge of the world.
// Sealed doors stop being solid by being rewritten to floor.

tile_coord :: proc(v: f32) -> i32 {
	// World position to tile index, floor division. Plain integer
	// division truncates toward zero, which puts world x = -1 in tile
	// 0 instead of tile -1 — and tile -1 is the void that keeps
	// things on the map. Floor keeps negative space solid.
	return i32(math.floor(v / TILE_SIZE))
}

overlaps_solid :: proc(m: Tilemap, r: rl.Rectangle) -> bool {
	// Whether a world-space box overlaps any wall or void tile. Scans
	// just the tile range under the box (usually 1 to 4 cells). The
	// far edges divide in float space: truncating the position to an
	// int first would let a box sink a fraction of a pixel into a wall
	// undetected. The 0.01 keeps an edge sitting exactly on a tile
	// boundary from counting as inside the next tile.
	x0 := tile_coord(r.x)
	y0 := tile_coord(r.y)
	x1 := tile_coord(r.x + r.width - 0.01)
	y1 := tile_coord(r.y + r.height - 0.01)
	for ty in y0 ..= y1 {
		for tx in x0 ..= x1 {
			if tile_at(m, tx, ty) in SOLID_TILES {
				return true
			}
		}
	}
	return false
}

move_and_slide :: proc(m: Tilemap, pos: ^rl.Vector2, col: Collider,
                       delta: rl.Vector2) -> (hit_x, hit_y: bool) {
	// Moves a collider by delta, one axis at a time. When an axis hits
	// a solid tile, the position snaps flush against it and that axis
	// reports a hit; the other axis still moves, which is what makes
	// walls slideable instead of sticky. Returns which axes hit.

	// --- X axis ---
	pos.x += delta.x
	r := rl.Rectangle{pos.x + col.offset.x, pos.y + col.offset.y,
	                  col.size.x, col.size.y}
	if overlaps_solid(m, r) {
		hit_x = true
		if delta.x > 0 { // moving right: flush against the tile's left edge
			edge := tile_coord(r.x + r.width - 0.01) * TILE_SIZE
			pos.x = f32(edge) - col.size.x - col.offset.x
		} else if delta.x < 0 { // moving left: flush against the right edge
			edge := (tile_coord(r.x) + 1) * TILE_SIZE
			pos.x = f32(edge) - col.offset.x
		}
	}
	// --- Y axis ---
	pos.y += delta.y
	r = rl.Rectangle{pos.x + col.offset.x, pos.y + col.offset.y,
	                 col.size.x, col.size.y}
	if overlaps_solid(m, r) {
		hit_y = true
		if delta.y > 0 {
			edge := tile_coord(r.y + r.height - 0.01) * TILE_SIZE
			pos.y = f32(edge) - col.size.y - col.offset.y
		} else if delta.y < 0 {
			edge := (tile_coord(r.y) + 1) * TILE_SIZE
			pos.y = f32(edge) - col.offset.y
		}
	}
	return
}
