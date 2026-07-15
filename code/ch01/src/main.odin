// Chapter 1: a window, a game loop, and a bobbing crown.
//
// This is the whole "engine": open a window, then loop forever doing
// update-a-little, draw-everything. Every later chapter keeps exactly
// this shape and only grows the two halves of the loop.

package crypt

import "core:math"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
// The palette of the crypt: near-black purple and old gold.
BACKGROUND_COLOR :: rl.Color{24, 20, 37, 255}
CROWN_COLOR :: rl.Color{232, 193, 112, 255}

draw_crown :: proc(cx, cy: i32) {
	// Draws a crown of plain shapes centered-ish on (cx, cy), in screen
	// coordinates (origin top-left, y grows downward). Programmer art;
	// the real crown is at the bottom of the crypt.
	left := cx - 60
	top := cy - 40
	// The band.
	rl.DrawRectangle(left, top + 50, 120, 30, CROWN_COLOR)
	// Three prongs, rendered as triangles. Vertices must be given in
	// counter-clockwise order or raylib culls the triangle entirely.
	for i in i32(0) ..< 3 {
		px := left + i * 40
		rl.DrawTriangle({f32(px), f32(top + 50)},
		                {f32(px + 40), f32(top + 50)},
		                {f32(px + 20), f32(top)},
		                CROWN_COLOR)
	}
	// The jewel, set in the middle of the band.
	rl.DrawCircle(cx, cy + 25, 9, {165, 48, 48, 255})
}

main :: proc() {
	// HighDPI must be requested before the window exists. Without it, a
	// display at 200% scaling shows the window at half the intended size.
	rl.SetConfigFlags({.WINDOW_HIGHDPI})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Crypt of Odin")
	defer rl.CloseWindow() // runs when main exits, however it exits
	rl.SetTargetFPS(60)

	elapsed: f32

	for !rl.WindowShouldClose() {
		// --- Update ---
		// dt is the previous frame's duration in seconds. Anything that
		// moves gets multiplied by it, so speed is per-second, not per-frame.
		dt := rl.GetFrameTime()
		elapsed += dt
		// A gentle bob: 10 pixels of amplitude, one full cycle per two seconds.
		bob := i32(10 * math.sin(elapsed * math.PI))

		// --- Draw ---
		// Immediate mode: nothing persists between frames. Clear, then
		// redraw the entire scene, every frame.
		rl.BeginDrawing()
		rl.ClearBackground(BACKGROUND_COLOR)
		draw_crown(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 - 40 + bob)
		title: cstring = "CRYPT OF ODIN"
		title_width := rl.MeasureText(title, 40)
		rl.DrawText(title, (SCREEN_WIDTH - title_width) / 2, 300, 40,
		            CROWN_COLOR)
		subtitle: cstring = "a roguelite, eventually"
		sub_width := rl.MeasureText(subtitle, 20)
		rl.DrawText(subtitle, (SCREEN_WIDTH - sub_width) / 2, 350, 20,
		            rl.LIGHTGRAY)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()
	}
}
