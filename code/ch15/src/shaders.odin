// Loading and feeding the game's two fragment shaders.
//
// The GLSL sources live in shaders/ (next to src/, not under assets/:
// they are code we maintain, not art we licensed) in two dialects:
// *-330.fs for desktop OpenGL, *-100.fs twins for the web build.
// Which dialect loads is decided at compile time; nothing else in the
// game knows there are two.

package crypt

import rl "vendor:raylib"

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
	GLSL_SUFFIX :: "-100.fs"
} else {
	GLSL_SUFFIX :: "-330.fs"
}

Fx :: struct {
	// The shaders plus the one uniform location that changes at draw
	// time. Locations are looked up once at load; asking by name every
	// frame works too, but a location is an int and the name lookup
	// is a string search.
	outline:    rl.Shader,
	crt:        rl.Shader,
	region_loc: i32,
}

load_fx :: proc(atlas: ^Atlas, canvas_w, canvas_h: i32) -> (fx: Fx) {
	// Loads both shaders and sets every uniform that never changes:
	// the atlas texel size, the outline color, the canvas resolution.
	// The nil means "keep raylib's default vertex shader"; these
	// effects only bend fragments.
	fx.outline = rl.LoadShader(nil, "shaders/outline" + GLSL_SUFFIX)
	fx.region_loc = rl.GetShaderLocation(fx.outline, "region")
	texel := rl.Vector2{1 / f32(atlas.texture.width),
	                    1 / f32(atlas.texture.height)}
	rl.SetShaderValue(fx.outline,
	                  rl.GetShaderLocation(fx.outline, "texelSize"),
	                  &texel, .VEC2)
	outline_color := rl.Vector4{1, 0.84, 0.2, 1} // gold, like the HUD
	rl.SetShaderValue(fx.outline,
	                  rl.GetShaderLocation(fx.outline, "outlineColor"),
	                  &outline_color, .VEC4)
	fx.crt = rl.LoadShader(nil, "shaders/crt" + GLSL_SUFFIX)
	resolution := rl.Vector2{f32(canvas_w), f32(canvas_h)}
	rl.SetShaderValue(fx.crt,
	                  rl.GetShaderLocation(fx.crt, "resolution"),
	                  &resolution, .VEC2)
	return
}

destroy_fx :: proc(fx: ^Fx) {
	rl.UnloadShader(fx.outline)
	rl.UnloadShader(fx.crt)
}

set_outline_region :: proc(fx: Fx, atlas: ^Atlas, src: rl.Rectangle) {
	// Points the outline shader at one sprite's atlas cell, inset half
	// a texel so the clamped neighbor samples can't bleed color from
	// the sprite next door.
	tw := f32(atlas.texture.width)
	th := f32(atlas.texture.height)
	region := rl.Vector4{
		(src.x + 0.5) / tw, (src.y + 0.5) / th,
		(src.x + src.width - 0.5) / tw,
		(src.y + src.height - 0.5) / th,
	}
	rl.SetShaderValue(fx.outline, fx.region_loc, &region, .VEC4)
}
