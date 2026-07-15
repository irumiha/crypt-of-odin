// The camera: a moving window over a world bigger than the screen.
//
// raylib's Camera2D does the actual work (everything drawn between
// BeginMode2D and EndMode2D is shifted by it); this file only decides
// where it should look.

package crypt

import "core:math"
import rl "vendor:raylib"

make_camera :: proc(screen_size: rl.Vector2) -> rl.Camera2D {
	// A camera whose `offset` pins the watched point (`target`) to the
	// middle of the screen.
	return {offset = screen_size * 0.5, zoom = 1}
}

Viewport :: struct {
	// Where the fixed logical frame lands inside the real window:
	// integer-scaled, centered, letterboxed. The world never learns
	// the window's size; presentation is the only thing that scales.
	dest:                 rl.Rectangle,
	logical_w, logical_h: i32,
}

compute_viewport :: proc(logical_w, logical_h: i32) -> Viewport {
	// The biggest integer scale that fits the physical framebuffer,
	// converted back to raylib's screen units for the final blit (on a
	// HiDPI display those units are scaled by the OS factor, so doing
	// the integer math in physical pixels keeps texels square).
	dpi := rl.GetWindowScaleDPI().x
	phys_w := f32(rl.GetRenderWidth())
	phys_h := f32(rl.GetRenderHeight())
	s := max(1, math.floor(min(phys_w / f32(logical_w),
	                           phys_h / f32(logical_h))))
	w := s * f32(logical_w) / dpi
	h := s * f32(logical_h) / dpi
	return {
		dest = {(f32(rl.GetScreenWidth()) - w) / 2,
		        (f32(rl.GetScreenHeight()) - h) / 2, w, h},
		logical_w = logical_w, logical_h = logical_h,
	}
}

mouse_logical :: proc(vp: Viewport) -> rl.Vector2 {
	// The mouse position in logical-frame coordinates, compensating
	// for the letterbox offset and the blit scale.
	m := rl.GetMousePosition()
	return {(m.x - vp.dest.x) * f32(vp.logical_w) / vp.dest.width,
	        (m.y - vp.dest.y) * f32(vp.logical_h) / vp.dest.height}
}

camera_follow :: proc(cam: ^rl.Camera2D, target: rl.Vector2,
                      map_size: rl.Vector2, dt: f32, speed: f32 = 10) {
	// Eases the camera toward the target, then clamps it so the view
	// never shows past the map's edges. The easing factor is scaled by
	// dt, so the glide feels the same at any frame rate; lower speed
	// gives a slower pan (room transitions use 6).
	ease := min(f32(1), speed * dt)
	cam.target += (target - cam.target) * ease
	// Half a screen of margin on each side keeps the view inside the map.
	half_view := cam.offset / cam.zoom
	cam.target.x = clamp(cam.target.x, half_view.x, map_size.x - half_view.x)
	cam.target.y = clamp(cam.target.y, half_view.y, map_size.y - half_view.y)
}
