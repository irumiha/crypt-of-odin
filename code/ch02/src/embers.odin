// Golden embers drifting up around the title-screen ring.
//
// The first homegrown file, and a miniature of how the whole game
// will manage short-lived things: plain value structs in a dynamic
// array, updated in place, removed by swap-and-shrink. A package is
// its directory: no import needed, main.odin just sees these names.

package crypt

import "core:math/rand"
import rl "vendor:raylib"

Ember :: struct {
	// A plain value type: no `new`, no null, no ceremony. Copying one
	// copies it; nothing can hold a reference to it behind your back.
	pos:      rl.Vector2,
	vel:      rl.Vector2,
	life:     f32, // seconds remaining
	max_life: f32, // starting life, kept so draw can fade proportionally
}

EMBER_COLOR :: rl.Color{232, 193, 112, 255}

spawn_ember :: proc(x, y: f32) -> Ember {
	// A new ember somewhere near (x, y), drifting upward with a
	// randomized speed and lifespan. Odin seeds its default random
	// generator on startup; nobody has to remember to.
	life := rand.float32_range(2, 4)
	return {
		pos      = {x + rand.float32_range(-80, 80), y},
		vel      = {rand.float32_range(-12, 12), rand.float32_range(-65, -25)},
		life     = life,
		max_life = life,
	}
}

embers_update :: proc(embers: ^[dynamic]Ember, dt: f32) {
	// Moves every ember and removes the expired ones. Takes a pointer
	// because it mutates the array, and the signature says so.
	for &e in embers^ {
		e.pos += e.vel * dt // Vector2 is a [2]f32: arithmetic just works
		e.life -= dt
	}
	// Compact away the dead: swap the last ember into the hole, shrink
	// by one. No shifting, no allocation; order changes, which embers
	// don't mind. The same idiom despawns enemies later on.
	for i := 0; i < len(embers); {
		if embers[i].life <= 0 {
			unordered_remove(embers, i)
		} else {
			i += 1
		}
	}
}

embers_draw :: proc(embers: []Ember) {
	// Draws each ember as a small circle, fading out as life runs down.
	// A slice, not a pointer: drawing has no business mutating.
	for e in embers {
		alpha := u8(255 * e.life / e.max_life)
		rl.DrawCircle(i32(e.pos.x), i32(e.pos.y), 2,
		              {EMBER_COLOR.r, EMBER_COLOR.g, EMBER_COLOR.b, alpha})
	}
}
