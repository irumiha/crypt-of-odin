// Drawing sprites out of the atlas: static ones and looping animations.

package crypt

import rl "vendor:raylib"

Anim_Sprite :: struct {
	// A looping animation: which frames, how fast, where we are.
	frames:         []rl.Rectangle,
	secs_per_frame: f32,
	timer:          f32, // accumulates dt until one frame's worth passes
	index:          int, // current frame
}

make_anim_sprite :: proc(atlas: ^Atlas, name: string,
                         fps: f32 = 8) -> Anim_Sprite {
	// An animation from the atlas by base name, e.g. "knight_m_idle_anim"
	// collects knight_m_idle_anim_f0..f2. fps is animation speed, not
	// render speed; the game still draws at 60.
	return {frames = atlas_frames(atlas, name), secs_per_frame = 1.0 / fps}
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
                    scale: f32) {
	// Draws the current frame at pos, scaled. Copies the frame's source
	// rectangle from the atlas texture onto a destination rectangle on
	// screen (raylib's DrawTexturePro).
	src := s.frames[s.index]
	dest := rl.Rectangle{pos.x, pos.y,
	                     src.width * scale, src.height * scale}
	rl.DrawTexturePro(atlas.texture, src, dest, {0, 0}, 0, rl.WHITE)
}

atlas_draw :: proc(atlas: ^Atlas, name: string, pos: rl.Vector2,
                   scale: f32) {
	// A single static sprite by name, scaled.
	src := atlas_rect(atlas, name)
	dest := rl.Rectangle{pos.x, pos.y, src.width * scale,
	                     src.height * scale}
	rl.DrawTexturePro(atlas.texture, src, dest, {0, 0}, 0, rl.WHITE)
}
