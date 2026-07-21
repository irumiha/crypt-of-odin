// Headless tests for the typed-art decoder: grids to image, no
// window and no GPU (raylib image procs are CPU-side).

package tests

import "core:testing"
import rl "vendor:raylib"
import crypt "../src"

@(test)
grid_decodes_to_pixels :: proc(t: ^testing.T) {
	strips := []crypt.Art_Strip{
		{name = "dot", frames = 1, rows = {
			"k...............",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"...............g",
		}},
	}
	img := crypt.render_art(strips)
	defer rl.UnloadImage(img)
	testing.expect_value(t, img.width, i32(16))
	testing.expect_value(t, img.height, i32(16))
	ink := rl.GetImageColor(img, 0, 0)
	testing.expect_value(t, ink, rl.Color{26, 20, 31, 255})
	gold := rl.GetImageColor(img, 15, 15)
	testing.expect_value(t, gold, rl.Color{255, 196, 64, 255})
	blank := rl.GetImageColor(img, 1, 0)
	testing.expect_value(t, blank.a, u8(0))
}

@(test)
game_art_is_well_formed :: proc(t: ^testing.T) {
	// Decoding asserts on any bad row width or unknown palette
	// character, so "it renders" is the whole test.
	img := crypt.render_art(crypt.ART)
	defer rl.UnloadImage(img)
	testing.expect(t, img.height ==
	               i32(len(crypt.ART) * crypt.SPRITE_SIZE))
}

@(test)
strip_lays_frames_side_by_side :: proc(t: ^testing.T) {
	// A 2-frame strip: frame 0 all ink, frame 1 all gold. The image
	// is 32 wide and the pixel at x=16 belongs to frame 1.
	rows: [crypt.SPRITE_SIZE]string
	for &row in rows {
		row = "kkkkkkkkkkkkkkkkgggggggggggggggg"
	}
	strips := []crypt.Art_Strip{{name = "two", frames = 2, rows = rows}}
	img := crypt.render_art(strips)
	defer rl.UnloadImage(img)
	testing.expect_value(t, img.width, i32(32))
	testing.expect_value(t, rl.GetImageColor(img, 15, 8),
	                     rl.Color{26, 20, 31, 255})
	testing.expect_value(t, rl.GetImageColor(img, 16, 8),
	                     rl.Color{255, 196, 64, 255})
}
