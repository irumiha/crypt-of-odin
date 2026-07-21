// Renders the ch17 typed-art sheet to atlas_preview.png at 8x, for
// eyeballing the art without launching the game. Pure CPU: runs
// headless. Usage: odin run tools/preview_art
package preview

import rl "vendor:raylib"
import crypt "../../code/ch17/src"

main :: proc() {
	img := crypt.render_art(crypt.ART)
	defer rl.UnloadImage(img)
	rl.ImageResizeNN(&img, img.width * 8, img.height * 8)
	rl.ExportImage(img, "atlas_preview.png")
}
