// Drawing sprites out of the atlas: static ones and looping animations.
//
// Changed in Chapter 5: an Anim_Sprite remembers which animation it is
// playing (so set_anim can switch between idle and run without
// restarting every frame) and can draw mirrored for left-facing.

package crypt

import rl "vendor:raylib"

Anim_Sprite :: struct {
	// A looping animation: which frames, how fast, where we are.
	anim:           string, // base name of the animation currently playing
	frames:         []rl.Rectangle,
	secs_per_frame: f32,
	timer:          f32, // accumulates dt until one frame's worth passes
	index:          int, // current frame
	scale:          f32,
	flip_x:         bool, // draw mirrored (the sprite faces left)
}

make_anim_sprite :: proc(atlas: ^Atlas, name: string,
                         scale: f32 = 4, fps: f32 = 8) -> Anim_Sprite {
	// An animation from the atlas by base name, e.g. "knight_m_idle_anim"
	// collects knight_m_idle_anim_f0..f3. fps is animation speed, not
	// render speed; the game still draws at 60.
	return {anim = name, frames = atlas_frames(atlas, name),
	        secs_per_frame = 1.0 / fps, scale = scale}
}

make_static_sprite :: proc(atlas: ^Atlas, name: string,
                           scale: f32 = 4) -> Anim_Sprite {
	// A one-frame "animation" for things that don't animate (swords,
	// skulls), so everything drawn is the same component type.
	return {anim = name, frames = atlas_static(atlas, name),
	        secs_per_frame = 1, scale = scale}
}

set_anim :: proc(s: ^Anim_Sprite, atlas: ^Atlas, name: string) {
	// Switches to another animation. A no-op when it is already
	// playing, so systems can assert the desired animation every frame
	// without resetting it to frame zero each time.
	if s.anim != name {
		s.anim = name
		s.frames = atlas_frames(atlas, name)
		s.timer = 0
		s.index = 0
	}
}

sprite_width :: proc(s: Anim_Sprite) -> f32 {
	// On-screen width of the current frame, scale included.
	return s.frames[s.index].width * s.scale
}

sprite_height :: proc(s: Anim_Sprite) -> f32 {
	// On-screen height of the current frame, scale included.
	return s.frames[s.index].height * s.scale
}

sprite_update :: proc(s: ^Anim_Sprite, dt: f32) {
	// Advances the animation clock. The `for` (not `if`) means a long
	// frame hitch skips exactly the frames it should.
	s.timer += dt
	for s.timer >= s.secs_per_frame {
		s.timer -= s.secs_per_frame
		s.index = (s.index + 1) % len(s.frames)
	}
}

sprite_draw :: proc(s: Anim_Sprite, atlas: ^Atlas, pos: rl.Vector2,
                    tint: rl.Color = rl.WHITE) {
	// Draws the current frame at pos. A negative source width tells
	// raylib to sample the region right-to-left: a free horizontal
	// flip, no second set of art required. The tint is how hurt-flashes
	// reach the sprite without the sprite knowing about combat.
	src := s.frames[s.index]
	if s.flip_x {
		src.width = -src.width
	}
	dest := rl.Rectangle{pos.x, pos.y,
	                     s.frames[s.index].width * s.scale,
	                     s.frames[s.index].height * s.scale}
	rl.DrawTexturePro(atlas.texture, src, dest, {0, 0}, 0, tint)
}

atlas_draw :: proc(atlas: ^Atlas, name: string, pos: rl.Vector2,
                   scale: f32) {
	// A single static sprite by name, scaled.
	src := atlas_rect(atlas, name)
	dest := rl.Rectangle{pos.x, pos.y, src.width * scale,
	                     src.height * scale}
	rl.DrawTexturePro(atlas.texture, src, dest, {0, 0}, 0, rl.WHITE)
}
