// The camera: a moving window over a world bigger than the screen.
//
// raylib's Camera2D does the actual work (everything drawn between
// BeginMode2D and EndMode2D is shifted by it); this file only decides
// where it should look.

package crypt

import rl "vendor:raylib"

make_camera :: proc(screen_size: rl.Vector2) -> rl.Camera2D {
	// A camera whose `offset` pins the watched point (`target`) to the
	// middle of the screen.
	return {offset = screen_size * 0.5, zoom = 1}
}

adapt_to_dpi :: proc(cam: ^rl.Camera2D, screen_size: rl.Vector2) {
	// raylib scales screen-space drawing on HiDPI displays, but resets
	// the matrix inside BeginMode2D, so world rendering must bake the
	// DPI scale into the camera itself: zoom by the scale, and pin the
	// target to the center of the real framebuffer. A no-op at scale 1,
	// and camera_follow's clamps stay correct because they divide by
	// zoom.
	s := rl.GetWindowScaleDPI().x
	cam.zoom = s
	cam.offset = screen_size * (0.5 * s)
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
