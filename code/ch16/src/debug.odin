// The debug instrument panel: god powers for the person testing.
//
// F1 toggles it. While it's on: N toggles noclip, F2 cycles the time
// scale, and the main file wires T (teleport to cursor) and E (spawn
// a critter at cursor) because those need its spawn context. Debug
// tooling reads raw keys on purpose; the action map is for gameplay,
// and nobody rebinds their debugger.

package crypt

import "core:fmt"
import rl "vendor:raylib"

Debug :: struct {
	enabled:    bool,
	noclip:     bool, // the player ignores walls while true
	time_scale: f32,
}

@(rodata)
TIME_SCALES := [3]f32{0.2, 1, 3}

init_debug :: proc() -> Debug {
	return {time_scale = 1}
}

debug_update :: proc(d: ^Debug) {
	// Handles the debug-mode toggles. Runs every frame, cheap when off.
	if rl.IsKeyPressed(.F1) {
		d.enabled = !d.enabled
	}
	if d.enabled {
		if rl.IsKeyPressed(.N) {
			d.noclip = !d.noclip
		}
		if rl.IsKeyPressed(.F2) {
			at := 0
			for s, i in TIME_SCALES {
				if s == d.time_scale {
					at = i
				}
			}
			d.time_scale = TIME_SCALES[(at + 1) % len(TIME_SCALES)]
		}
	}
}

mouse_world :: proc(cam: rl.Camera2D, vp: Viewport) -> rl.Vector2 {
	// The mouse position in world coordinates: letterbox first (window
	// to logical frame), then the camera transform, inverted.
	return rl.GetScreenToWorld2D(mouse_logical(vp), cam)
}

debug_draw_world :: proc(d: Debug, w: ^World) {
	// World-space overlay (call between BeginMode2D and EndMode2D):
	// every collider box, outlined. Seeing hitboxes ends arguments.
	if d.enabled {
		for i in query(w, {.Position, .Collider}) {
			rl.DrawRectangleLinesEx(collider_rect(w, i), 2, rl.RED)
		}
	}
}

debug_draw_panel :: proc(d: Debug, w: ^World, cam: rl.Camera2D,
                         vp: Viewport) {
	// Screen-space overlay: the status line, plus a full dump of any
	// entity the mouse hovers (the print test, aimed with the cursor).
	if d.enabled {
		rl.DrawText(fmt.ctprintf(
			"DEBUG  [N]oclip:%v  [F2]time:x%.1f  [T]eleport [E]spawn",
			d.noclip, d.time_scale), 10, 130, 20, rl.RED)
		mw := mouse_world(cam, vp)
		for i in query(w, {.Position, .Collider}) {
			if rl.CheckCollisionPointRec(mw, collider_rect(w, i)) {
				rl.DrawText(fmt.ctprintf("%s", dump(w, entity(w, i))),
				            10, 160, 20, rl.YELLOW)
				break
			}
		}
	}
}
