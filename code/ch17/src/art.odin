// The game's art, typed in. Every sprite is a string grid: one
// character per pixel, keyed to the palette below. Animated sprites
// are filmstrips — three 16-wide frames side by side in one grid —
// so a listing reads like a strip of film.
//
// A wrong character fails loudly at load (see palette_color), and a
// wrong row width fails in render_art: the compiler and the loader
// are the type-in reader's proofreaders.

package crypt

import rl "vendor:raylib"

SPRITE_SIZE :: 16

Palette_Entry :: struct {
	ch:    u8,
	color: rl.Color,
}

PALETTE :: [?]Palette_Entry{
	{'.', {0, 0, 0, 0}},         // transparent
	{'k', {26, 20, 31, 255}},    // ink: outlines
	{'d', {56, 50, 68, 255}},    // stone, dark: floors
	{'s', {90, 83, 102, 255}},   // stone, mid: walls
	{'S', {132, 126, 143, 255}}, // stone, light: highlights
	{'m', {120, 130, 145, 255}}, // metal: armor, the sword
	{'w', {222, 215, 202, 255}}, // bone: skeletons, UI
	{'g', {255, 196, 64, 255}},  // gold: coins, trim
	{'f', {224, 164, 126, 255}}, // flesh: faces
	{'r', {178, 54, 54, 255}},   // red: hearts, imps
	{'G', {84, 150, 75, 255}},   // green: goblins, flasks
	{'b', {70, 110, 180, 255}},  // blue: flasks
	{'p', {122, 72, 160, 255}},  // purple: demons
}

Art_Strip :: struct {
	// One sprite or one animation. rows are frames*16 characters
	// wide; frame f occupies columns f*16 ..< (f+1)*16.
	name:   string,
	frames: int,
	rows:   [SPRITE_SIZE]string,
}
