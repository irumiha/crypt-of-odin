// Asset loading: the texture atlas and its index.
//
// All of the game's art lives in one image (the atlas). This file
// loads it plus the pack's `tile_list` file, so the rest of the game
// can ask for sprites by name instead of by pixel coordinates.

package crypt

import "core:c"
import "core:fmt"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

Atlas :: struct {
	// One texture and a name -> region index, loaded from the tile
	// list that ships with the art pack. `anims` caches frame lists
	// so every sprite playing the same animation shares one slice;
	// Odin has no destructors, so shared immutable data beats
	// per-sprite copies.
	texture: rl.Texture2D,
	rects:   map[string]rl.Rectangle,
	anims:   map[string][]rl.Rectangle,
}

load_atlas :: proc(image_path, index_path: string) -> (atlas: Atlas) {
	// Uploads the atlas image to the GPU and parses its index file.
	// raylib's own file loader instead of core:os: one interface for
	// every platform the game will ever run on.
	atlas.texture = rl.LoadTexture(fmt.ctprintf("%s", image_path))
	fmt.assertf(rl.IsTextureValid(atlas.texture),
	            "missing atlas image: %s", image_path)
	size: c.int
	data := rl.LoadFileData(fmt.ctprintf("%s", index_path), &size)
	assert(data != nil, "missing atlas index")
	defer rl.UnloadFileData(data)
	// Each line: name x y width height. Short or empty lines (like
	// the trailing newline) fail the length check and are skipped.
	rest := string(data[:size])
	for line in strings.split_lines_iterator(&rest) {
		parts := strings.fields(line, context.temp_allocator)
		if len(parts) >= 5 {
			px :: proc(s: string) -> f32 {
				// A field that isn't a number means a corrupt index
				// file; better to stop here than draw garbage regions.
				v, ok := strconv.parse_f64(s)
				fmt.assertf(ok, "bad atlas index field: %q", s)
				return f32(v)
			}
			atlas.rects[strings.clone(parts[0])] = rl.Rectangle{
				x      = px(parts[1]),
				y      = px(parts[2]),
				width  = px(parts[3]),
				height = px(parts[4]),
			}
		}
	}
	return
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
	// following the art pack's frame-naming convention. Built once
	// per name, then served from the cache.
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
