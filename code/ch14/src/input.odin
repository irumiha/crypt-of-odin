// The action map: gameplay code asks about intentions ("is the player
// moving left?"), never about keys. Bindings live in one table, so
// WASD and arrows both work today, rebinding is a data change, and a
// gamepad can join later without touching any system.

package crypt

import "core:math/linalg"
import rl "vendor:raylib"

Action :: enum {
	Move_Left, Move_Right, Move_Up, Move_Down, Attack, Pause,
}

@(rodata)
BINDINGS := [Action][]rl.KeyboardKey{
	.Move_Left  = {.A, .LEFT},
	.Move_Right = {.D, .RIGHT},
	.Move_Up    = {.W, .UP},
	.Move_Down  = {.S, .DOWN},
	.Attack     = {.SPACE, .J},
	.Pause      = {.ESCAPE, .P},
}

is_down :: proc(a: Action) -> bool {
	// True while any key bound to the action is held.
	for key in BINDINGS[a] {
		if rl.IsKeyDown(key) {
			return true
		}
	}
	return false
}

was_pressed :: proc(a: Action) -> bool {
	// True on the frame any key bound to the action went down.
	for key in BINDINGS[a] {
		if rl.IsKeyPressed(key) {
			return true
		}
	}
	return false
}

move_axis :: proc() -> (v: rl.Vector2) {
	// The player's movement intention as a unit vector (or zero).
	// Normalized so holding two keys doesn't move 41% faster
	// diagonally.
	if is_down(.Move_Left) do v.x -= 1
	if is_down(.Move_Right) do v.x += 1
	if is_down(.Move_Up) do v.y -= 1
	if is_down(.Move_Down) do v.y += 1
	if linalg.length(v) > 0 {
		v = linalg.normalize(v)
	}
	return
}
