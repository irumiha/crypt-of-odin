// A pixel editor for the typed string-grid art in code/ch17/src/art.odin.
// Loads the real ART at compile time, edits strips in memory, and exports
// the selected strip as an Art_Strip literal (clipboard + stdout) for
// manual paste-over. Never writes to disk. Usage: odin run tools/art_editor
package art_editor

import "core:fmt"
import "core:strings"
import crypt "../../code/ch17/src"

MAX_W :: 3 * crypt.SPRITE_SIZE
UNDO_CAP :: 100

Grid :: [crypt.SPRITE_SIZE][MAX_W]u8

Strip_Edit :: struct {
	name:   string,
	frames: int,
	grid:   Grid, // live pixels, palette chars; cols 0 ..< frames*SPRITE_SIZE
	orig:   Grid, // as decoded — the sidebar stars strips where grid != orig
	undo:   [dynamic]Grid,
}

PAL := crypt.PALETTE // materialized so it can be indexed at runtime

decode_strip :: proc(s: crypt.Art_Strip) -> (e: Strip_Edit) {
	e.name = s.name
	e.frames = s.frames
	w := s.frames * crypt.SPRITE_SIZE
	for row, y in s.rows {
		assert(len(row) == w, "row width != frames*16")
		for x in 0 ..< w do e.grid[y][x] = row[x]
	}
	e.orig = e.grid
	return
}

strip_row :: proc(e: ^Strip_Edit, y: int) -> string {
	return string(e.grid[y][:e.frames * crypt.SPRITE_SIZE])
}

export_literal :: proc(e: ^Strip_Edit, allocator := context.allocator) -> string {
	b := strings.builder_make(allocator)
	fmt.sbprintf(&b, "\t{{name = %q, frames = %d, rows = {{\n", e.name, e.frames)
	for y in 0 ..< crypt.SPRITE_SIZE do fmt.sbprintf(&b, "\t\t%q,\n", strip_row(e, y))
	strings.write_string(&b, "\t}},\n")
	return strings.to_string(b)
}

load_strips :: proc() -> [dynamic]Strip_Edit {
	edits: [dynamic]Strip_Edit
	for s in crypt.ART do append(&edits, decode_strip(s))
	return edits
}

// Prove the encoder is byte-faithful for all real data before any editing.
self_check :: proc(edits: []Strip_Edit) {
	for s, i in crypt.ART {
		e := &edits[i]
		for y in 0 ..< crypt.SPRITE_SIZE {
			assert(strip_row(e, y) == s.rows[y], "round-trip mismatch")
		}
	}
}

main :: proc() {
	edits := load_strips()
	self_check(edits[:])
	fmt.printfln("self-check OK: %d strips round-trip byte-faithful", len(edits))
	fmt.print(export_literal(&edits[0]))
}
