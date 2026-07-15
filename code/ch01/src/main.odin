// Chapter 1: a window, a game loop, and a bobbing ring.
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
RING_COLOR :: rl.Color{232, 193, 112, 255}

draw_ring :: proc(cx, cy: i32) {
	// Draws the ring as plain shapes centered on (cx, cy), in screen
	// coordinates (origin top-left, y grows downward). Programmer art;
	// the real ring is at the bottom of the crypt.
	// The band. raylib has a primitive for exactly this shape.
	rl.DrawRing({f32(cx), f32(cy)}, 30, 45, 0, 360, 48, RING_COLOR)
	// The legend says the ring drips eight copies of itself every ninth
	// night. The art budget says three, still falling.
	for i in i32(0) ..< 3 {
		drop := rl.Vector2{f32(cx + (i - 1) * 26), f32(cy + 62 + (i % 2) * 10)}
		rl.DrawRing(drop, 4, 7, 0, 360, 24, RING_COLOR)
	}
	// The glint, rendered as two triangles. Vertices must be given in
	// counter-clockwise order or raylib culls the triangle entirely.
	gx, gy := f32(cx) + 26, f32(cy) - 26
	rl.DrawTriangle({gx - 7, gy}, {gx + 7, gy}, {gx, gy - 14}, rl.RAYWHITE)
	rl.DrawTriangle({gx + 7, gy}, {gx - 7, gy}, {gx, gy + 14}, rl.RAYWHITE)
	// The jewel, set in the band.
	rl.DrawCircle(cx, cy + 37, 9, {165, 48, 48, 255})
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
		draw_ring(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 - 40 + bob)
		title: cstring = "CRYPT OF ODIN"
		title_width := rl.MeasureText(title, 40)
		rl.DrawText(title, (SCREEN_WIDTH - title_width) / 2, 300, 40,
		            RING_COLOR)
		subtitle: cstring = "a roguelite, eventually"
		sub_width := rl.MeasureText(subtitle, 20)
		rl.DrawText(subtitle, (SCREEN_WIDTH - sub_width) / 2, 350, 20,
		            rl.LIGHTGRAY)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()
	}
}
