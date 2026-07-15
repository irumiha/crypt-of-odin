// Chapter 2: the Chapter 1 title scene, plus a field of embers.
//
// The embers live in `embers.odin`; this file owns their storage (a
// plain dynamic array) and decides when to spawn one. See also
// `tour.odin` in the chapter root for this chapter's language tour:
// odin run tour.odin -file

package crypt

import "core:math"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
// The palette of the crypt: near-black purple and old gold.
BACKGROUND_COLOR :: rl.Color{24, 20, 37, 255}
RING_COLOR :: rl.Color{232, 193, 112, 255}

draw_ring :: proc(cx, cy: i32) {
	// Draws the ring as plain shapes centered on (cx, cy).
	// Programmer art; the real ring is at the bottom of the crypt.
	// The band.
	rl.DrawRing({f32(cx), f32(cy)}, 30, 45, 0, 360, 48, RING_COLOR)
	// The drips: the legend says eight every ninth night; the art
	// budget says three.
	for i in i32(0) ..< 3 {
		drop := rl.Vector2{f32(cx + (i - 1) * 26), f32(cy + 62 + (i % 2) * 10)}
		rl.DrawRing(drop, 4, 7, 0, 360, 24, RING_COLOR)
	}
	// The glint, two triangles (counter-clockwise winding, or raylib
	// culls them).
	gx, gy := f32(cx) + 26, f32(cy) - 26
	rl.DrawTriangle({gx - 7, gy}, {gx + 7, gy}, {gx, gy - 14}, rl.RAYWHITE)
	rl.DrawTriangle({gx + 7, gy}, {gx - 7, gy}, {gx, gy + 14}, rl.RAYWHITE)
	// The jewel, set in the band.
	rl.DrawCircle(cx, cy + 37, 9, {165, 48, 48, 255})
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_HIGHDPI})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Crypt of Odin")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	elapsed: f32
	ember_field: [dynamic]Ember
	defer delete(ember_field)
	spawn_timer: f32

	for !rl.WindowShouldClose() {
		// --- Update ---
		dt := rl.GetFrameTime()
		elapsed += dt
		// A gentle bob: 10 pixels of amplitude, one full cycle per two seconds.
		bob := i32(10 * math.sin(elapsed * math.PI))
		// A countdown timer: refill on expiry, spawn one ember. The same
		// shape later paces weapon cooldowns.
		spawn_timer -= dt
		if spawn_timer <= 0 {
			spawn_timer = 0.03
			append(&ember_field,
			       spawn_ember(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 + 65))
		}
		embers_update(&ember_field, dt)

		// --- Draw ---
		rl.BeginDrawing()
		rl.ClearBackground(BACKGROUND_COLOR)
		embers_draw(ember_field[:]) // before the ring: embers rise behind it
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
