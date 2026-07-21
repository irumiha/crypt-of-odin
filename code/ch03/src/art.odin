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

// The art inventory. Every animated strip is three frames: the pose,
// the pose dropped one pixel (a bob), and a variation — a blink for
// idles, the mirrored stride for runs.
ART :: []Art_Strip{
	{name = "knight_m_idle_anim", frames = 3, rows = {
		"....kkkkkkkk........................kkkkkkkk....",
		"...kmmmmmmmmk.......kkkkkkkk.......kmmmmmmmmk...",
		"...kmSmmmmmSk......kmmmmmmmmk......kmSmmmmmSk...",
		"...kmmmmmmmmk......kmSmmmmmSk......kmmmmmmmmk...",
		"...kffffffffk......kffffffffk......kffffffffk...",
		"...kfkffffkfk......kfkffffkfk......kffffffffk...",
		"...kffffffffk......kffffffffk......kffffffffk...",
		"...kmmmmmmmmk......kmmmmmmmmk......kmmmmmmmmk...",
		"..kmmgmmmmgmmk....kmmgmmmmgmmk....kmmgmmmmgmmk..",
		"..kmk.mmmm.kmk....kmk.mmmm.kmk....kmk.mmmm.kmk..",
		"..kmk.mmmm.kmk....kmk.mmmm.kmk....kmk.mmmm.kmk..",
		"..kk..gggg..kk....kk..gggg..kk....kk..gggg..kk..",
		".....kmmmmk..........kmmmmk..........kmmmmk.....",
		"....kmk..kmk........kmk..kmk........kmk..kmk....",
		"....kmk..kmk........kmk..kmk........kmk..kmk....",
		"....kk....kk........kk....kk........kk....kk....",
	}},
	// The dungeon itself. Floors tile edge to edge under everything,
	// so no outlines: floor_1 is the plain slab with a few specks,
	// and 2..4 each add one crack. Mixed on a map they read as wear.
	{name = "floor_1", frames = 1, rows = {
		"dddddddddddddddd",
		"dddddddddddddddd",
		"ddddddkddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"ddddddddddddkddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddkdddddddddddd",
		"dddddddddddddddd",
		"ddddddddddkddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
	}},
	{name = "floor_2", frames = 1, rows = {
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"ddddkddddddddddd",
		"dddddkdddddddddd",
		"dddddkdddddddddd",
		"ddddddkddddddddd",
		"dddddddkdddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddkdddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
	}},
	{name = "floor_3", frames = 1, rows = {
		"dddddddddddddddd",
		"dddddddddddddddd",
		"ddddddddddddkddd",
		"dddddddddddkdddd",
		"dddddddddddkdddd",
		"ddddddddddkddddd",
		"dddddddddkdddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"ddddkddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
	}},
	{name = "floor_4", frames = 1, rows = {
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddkdddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"ddddddkddddddddd",
		"dddddddkkddddddd",
		"dddddddddkdddddd",
		"ddddddddddkddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
		"dddddddddddddddd",
	}},
	// Props. The coin is the one animated prop: face on, edge on,
	// face on with the shine swapped sides — a spin in three frames.
	{name = "coin_anim", frames = 3, rows = {
		"................................................",
		"................................................",
		"................................................",
		"......kkkk..............kk............kkkk......",
		".....kggggk...........kggk...........kggggk.....",
		"....kgwwgggk..........kggk..........kgggwwgk....",
		"....kgwggggk..........kwgk..........kggggwgk....",
		"....kggggggk..........kggk..........kggggggk....",
		"....kggggggk..........kggk..........kggggggk....",
		".....kggggk...........kggk...........kggggk.....",
		"......kkkk..............kk............kkkk......",
		"................................................",
		"................................................",
		"................................................",
		"................................................",
		"................................................",
	}},
	// A closed chest, drawn once for this chapter's demo scene only.
	{name = "chest_empty_open_anim", frames = 3, rows = {
		"................................................",
		"................................................",
		"..................................kkkkkkkkkkkk..",
		"..................................kffffffffffk..",
		"...................kkkkkkkkkk.....kkkkkkkkkkkk..",
		"..................kffffffffffk....kddddddddddk..",
		"...kkkkkkkkkk.....kffffffffffk....kddddddddddk..",
		"..kffffffffffk....kkkkkkkkkkkk....kddddddddddk..",
		"..kffffffffffk....kddddddddddk....kddddddddddk..",
		"..kkkkkkkkkkkk....kkkkkkkkkkkk....kkkkkkkkkkkk..",
		"..kfffkggkfffk....kfffkggkfffk....kfffkggkfffk..",
		"..kfffkggkfffk....kfffkggkfffk....kfffkggkfffk..",
		"..kffffffffffk....kffffffffffk....kffffffffffk..",
		"..kffffffffffk....kffffffffffk....kffffffffffk..",
		"..kffffffffffk....kffffffffffk....kffffffffffk..",
		"..kkkkkkkkkkkk....kkkkkkkkkkkk....kkkkkkkkkkkk..",
	}},
	// The decal left where an enemy falls: a bone skull, eye sockets
	// and the nose gap punched out in ink.
	{name = "skull", frames = 1, rows = {
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"......kkkk......",
		".....kwwwwk.....",
		".....kkwwkk.....",
		".....kwwwwk.....",
		"......kwwk......",
		"......kkkk......",
		"................",
		"................",
		"................",
	}},
}
