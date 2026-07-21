// Asset loading: the texture atlas.
//
// All of the game's art lives in one image (the atlas), built at load
// time from the typed strips in art.odin (render_art, build_atlas)
// instead of loaded from a pack on disk. The rest of the game still
// asks for sprites by name; only where the pixels come from changed.

package crypt

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

Atlas :: struct {
	// One texture and a name -> region index, built by build_atlas from
	// the typed strips in art.odin. `anims` caches frame lists so every
	// sprite playing the same animation shares one slice; Odin has no
	// destructors, so shared immutable data beats per-sprite copies.
	texture: rl.Texture2D,
	rects:   map[string]rl.Rectangle,
	anims:   map[string][]rl.Rectangle,
}

destroy_atlas :: proc(atlas: ^Atlas) {
	// The texture back to the GPU, the cloned keys and cached frame
	// lists back to the allocator. Deleting a map frees its own
	// storage, never what its keys and values point at. Every load_
	// in this game will have a destroy_; the habit starts here.
	rl.UnloadTexture(atlas.texture)
	for key in atlas.rects {
		delete(key)
	}
	for key, frames in atlas.anims {
		delete(key)
		delete(frames)
	}
	delete(atlas.rects)
	delete(atlas.anims)
}

atlas_rect :: proc(atlas: ^Atlas, name: string) -> rl.Rectangle {
	// The region of a named sprite. Unknown names are a programmer
	// error (a typo), so this asserts instead of returning an option.
	r, ok := atlas.rects[name]
	fmt.assertf(ok, "unknown sprite: %s", name)
	return r
}

atlas_frames :: proc(atlas: ^Atlas, name: string) -> []rl.Rectangle {
	// Collects name_f0, name_f1, ... into an animation's frame list,
	// the same frame-naming convention build_atlas registers strips
	// under. Built once per name, then served from the cache.
	if cached, ok := atlas.anims[name]; ok {
		return cached
	}
	frames: [dynamic]rl.Rectangle
	for i := 0; ; i += 1 {
		r, ok := atlas.rects[fmt.tprintf("%s_f%d", name, i)]
		if !ok do break
		append(&frames, r)
	}
	fmt.assertf(len(frames) > 0, "no frames for: %s", name)
	atlas.anims[strings.clone(name)] = frames[:]
	return frames[:]
}

atlas_static :: proc(atlas: ^Atlas, name: string) -> []rl.Rectangle {
	// A one-frame list for things that don't animate, cached like
	// the real animations so sprites can share it.
	if cached, ok := atlas.anims[name]; ok {
		return cached
	}
	frames := make([]rl.Rectangle, 1)
	frames[0] = atlas_rect(atlas, name)
	atlas.anims[strings.clone(name)] = frames
	return frames
}

palette_color :: proc(ch: u8) -> rl.Color {
	// The single source of color truth. An unknown character is a
	// typo in a grid; stop and say which one.
	for entry in PALETTE {
		if entry.ch == ch do return entry.color
	}
	fmt.assertf(false, "no palette entry for %q", rune(ch))
	return {}
}

render_art :: proc(strips: []Art_Strip) -> rl.Image {
	// Grids to pixels, one strip per row of the sheet. Pure CPU
	// work (raylib image procs), so the headless tests can see it.
	max_w := 1
	for strip in strips {
		max_w = max(max_w, strip.frames)
	}
	img := rl.GenImageColor(i32(max_w * SPRITE_SIZE),
	                        i32(len(strips) * SPRITE_SIZE), rl.BLANK)
	for strip, i in strips {
		fmt.assertf(strip.frames >= 1, "bad frame count: %s", strip.name)
		for row, y in strip.rows {
			fmt.assertf(len(row) == strip.frames * SPRITE_SIZE,
			            "row %d of %q is %d chars, want %d",
			            y, strip.name, len(row),
			            strip.frames * SPRITE_SIZE)
			for x in 0 ..< len(row) {
				rl.ImageDrawPixel(&img, i32(x),
				                  i32(i * SPRITE_SIZE + y),
				                  palette_color(row[x]))
			}
		}
	}
	return img
}

build_atlas :: proc(strips: []Art_Strip) -> (atlas: Atlas) {
	// The typed-art replacement for load_atlas: render the strips,
	// upload once, and register every frame under the same names
	// the rest of the game already asks for.
	img := render_art(strips)
	defer rl.UnloadImage(img)
	atlas.texture = rl.LoadTextureFromImage(img)
	assert(rl.IsTextureValid(atlas.texture), "atlas upload failed")
	for strip, i in strips {
		y := f32(i * SPRITE_SIZE)
		if strip.frames == 1 {
			atlas.rects[strings.clone(strip.name)] =
				rl.Rectangle{0, y, SPRITE_SIZE, SPRITE_SIZE}
		} else {
			for f in 0 ..< strip.frames {
				atlas.rects[fmt.aprintf("%s_f%d", strip.name, f)] =
					rl.Rectangle{f32(f * SPRITE_SIZE), y,
					             SPRITE_SIZE, SPRITE_SIZE}
			}
		}
	}
	return
}
