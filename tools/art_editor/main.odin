// A pixel editor for the typed string-grid art in code/ch17/src/art.odin.
// Loads the real ART at compile time, edits strips in memory, and exports
// the selected strip as an Art_Strip literal (clipboard + stdout) for
// manual paste-over. The only disk write is the ART_EDITOR_SHOT screenshot
// mode, used for automated UI verification. Usage: odin run tools/art_editor
package art_editor

import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"
import crypt "../../code/ch17/src"

MAX_W :: 3 * crypt.SPRITE_SIZE
UNDO_CAP :: 100

WIN_W :: 1280
WIN_H :: 720
SIDEBAR_W :: 220
LIST_ROW_H :: 20
CANVAS_X :: 240
CANVAS_Y :: 80
ZOOM :: 20
PAL_Y :: WIN_H - 64
PREVIEW_X :: 1140
PREVIEW_Y :: 8

// Palette selection keys, in PALETTE order.
PAL_KEYS :: [?]rl.KeyboardKey{
	.ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX, .SEVEN, .EIGHT, .NINE,
	.ZERO, .MINUS, .EQUAL, .BACKSPACE,
}
#assert(len(PAL_KEYS) == len(crypt.PALETTE))

Editor :: struct {
	edits:     [dynamic]Strip_Edit,
	sel:       int, // selected strip index
	color:     int, // selected palette index
	scroll:    int, // sidebar scroll offset, in rows
	onion:     bool,
	fps:       f32, // animation preview speed
	anim_t:    f32, // preview clock, in (fractional) frames
	scratch_n: int, // scratch strips created so far
}

visible_rows :: proc() -> int {
	return (WIN_H - 16) / LIST_ROW_H
}

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

draw_checker :: proc(px, py, size: i32) {
	h := size / 2
	c0 := rl.Color{52, 52, 60, 255}
	c1 := rl.Color{66, 66, 76, 255}
	rl.DrawRectangle(px, py, h, h, c0)
	rl.DrawRectangle(px + h, py, h, h, c1)
	rl.DrawRectangle(px, py + h, h, h, c1)
	rl.DrawRectangle(px + h, py + h, h, h, c0)
}

draw_sidebar :: proc(ed: ^Editor) {
	rl.DrawRectangle(0, 0, SIDEBAR_W, WIN_H, {30, 30, 36, 255})
	for i in ed.scroll ..< len(ed.edits) {
		y := i32((i - ed.scroll) * LIST_ROW_H + 8)
		if y > WIN_H - LIST_ROW_H do break
		e := &ed.edits[i]
		col := rl.LIGHTGRAY
		if i == ed.sel do col = rl.GOLD
		label := fmt.ctprintf("%s%s", e.grid != e.orig ? "*" : " ", e.name)
		rl.DrawText(label, 8, y, 12, col)
	}
}

draw_canvas :: proc(ed: ^Editor) {
	e := &ed.edits[ed.sel]
	w := e.frames * crypt.SPRITE_SIZE
	for y in 0 ..< crypt.SPRITE_SIZE {
		for x in 0 ..< w {
			px := i32(CANVAS_X + x * ZOOM)
			py := i32(CANVAS_Y + y * ZOOM)
			ch := e.grid[y][x]
			if ch == '.' do draw_checker(px, py, ZOOM)
			else do rl.DrawRectangle(px, py, ZOOM, ZOOM, crypt.palette_color(ch))
		}
	}
	gc := rl.Color{255, 255, 255, 28}
	for x in 0 ..= w {
		px := i32(CANVAS_X + x * ZOOM)
		rl.DrawLine(px, CANVAS_Y, px, CANVAS_Y + crypt.SPRITE_SIZE * ZOOM, gc)
	}
	for y in 0 ..= crypt.SPRITE_SIZE {
		py := i32(CANVAS_Y + y * ZOOM)
		rl.DrawLine(CANVAS_X, py, i32(CANVAS_X + w * ZOOM), py, gc)
	}
}

draw_palette :: proc(ed: ^Editor) {
	for p, i in PAL {
		px := i32(CANVAS_X + i * 48)
		py := i32(PAL_Y)
		if p.ch == '.' do draw_checker(px, py, 40)
		else do rl.DrawRectangle(px, py, 40, 40, p.color)
		if i == ed.color do rl.DrawRectangleLines(px - 2, py - 2, 44, 44, rl.RAYWHITE)
		rl.DrawText(fmt.ctprintf("%c", rune(p.ch)), px + 16, py + 44, 12, rl.LIGHTGRAY)
	}
}

update :: proc(ed: ^Editor) {
	m := rl.GetMousePosition()

	// Strip selection: arrows, sidebar click, wheel scroll.
	if rl.IsKeyPressed(.UP) do ed.sel = max(0, ed.sel - 1)
	if rl.IsKeyPressed(.DOWN) do ed.sel = min(len(ed.edits) - 1, ed.sel + 1)
	if wheel := rl.GetMouseWheelMove(); wheel != 0 && m.x < SIDEBAR_W {
		ed.scroll -= int(wheel)
	}
	if rl.IsMouseButtonPressed(.LEFT) && m.x < SIDEBAR_W && m.y >= 8 {
		i := ed.scroll + (int(m.y) - 8) / LIST_ROW_H
		if i < len(ed.edits) do ed.sel = i
	}
	if ed.sel < ed.scroll do ed.scroll = ed.sel
	if ed.sel >= ed.scroll + visible_rows() do ed.scroll = ed.sel - visible_rows() + 1
	ed.scroll = clamp(ed.scroll, 0, max(0, len(ed.edits) - visible_rows()))

	// Palette selection: number-row keys or swatch click.
	for k, i in PAL_KEYS do if rl.IsKeyPressed(k) do ed.color = i
	if rl.IsMouseButtonPressed(.LEFT) {
		for _, i in PAL {
			px := f32(CANVAS_X + i * 48)
			if m.x >= px && m.x < px + 40 && m.y >= f32(PAL_Y) && m.y < f32(PAL_Y) + 40 {
				ed.color = i
			}
		}
	}
}

main :: proc() {
	edits := load_strips()
	self_check(edits[:])
	ed := Editor{edits = edits, fps = 8}

	// ART_EDITOR_SHOT=<path>: save one screenshot after 60 frames and
	// exit — lets agents verify the UI without a human at the mouse.
	shot := os.get_env_alloc("ART_EDITOR_SHOT", context.allocator)

	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(WIN_W, WIN_H, "crypt art editor")
	rl.SetTargetFPS(60)
	frames_drawn := 0
	for !rl.WindowShouldClose() {
		update(&ed)
		rl.BeginDrawing()
		rl.ClearBackground({24, 24, 28, 255})
		draw_sidebar(&ed)
		draw_canvas(&ed)
		draw_palette(&ed)
		rl.EndDrawing()
		frames_drawn += 1
		if shot != "" && frames_drawn == 60 {
			// rl.TakeScreenshot always joins the given name onto
			// CORE.Storage.basePath (the working directory), so an
			// absolute ART_EDITOR_SHOT path never resolves. ExportImage
			// writes to the given path directly.
			img := rl.LoadImageFromScreen()
			rl.ExportImage(img, strings.clone_to_cstring(shot, context.temp_allocator))
			rl.UnloadImage(img)
			break
		}
		free_all(context.temp_allocator)
	}
	rl.CloseWindow()
}
