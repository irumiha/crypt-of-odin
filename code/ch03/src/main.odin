// Chapter 3: real pixel art. A tiled crypt floor, a few props, and a
// knight idling in the middle, all drawn from one texture atlas — built
// at load time from the typed strips in art.odin — at 2x scale
// (raylib's default point filtering keeps the pixels crisp).

package crypt

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
SCALE :: 2 // 16px art, 32px on screen
TILE_SIZE :: 16 * SCALE
BACKGROUND_COLOR :: rl.Color{24, 20, 37, 255}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_HIGHDPI})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Crypt of Odin")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	atlas := build_atlas(ART)
	defer destroy_atlas(&atlas) // runs before CloseWindow: GPU still up

	// The floor: one variant per cell, rolled once at startup and stored
	// flat (row-major); rolling in the draw loop would reshuffle the
	// floor sixty times a second. Weighted toward the plain tile so the
	// cracks read as wear, not rubble.
	COLS :: SCREEN_WIDTH / TILE_SIZE
	ROWS :: SCREEN_HEIGHT / TILE_SIZE + 1 // +1: 450 isn't divisible by 32
	floor_tiles: [dynamic]rl.Rectangle
	defer delete(floor_tiles)
	for _ in 0 ..< COLS * ROWS {
		name := "floor_1"
		if rand.float32() >= 0.9 {
			name = fmt.tprintf("floor_%d", 2 + rand.int_max(3))
		}
		append(&floor_tiles, atlas_rect(&atlas, name))
	}

	knight := make_anim_sprite(&atlas, "knight_m_idle_anim")
	knight_pos := rl.Vector2{
		(SCREEN_WIDTH - 16 * SCALE) / 2,
		(SCREEN_HEIGHT - 16 * SCALE) / 2,
	}
	coin := make_anim_sprite(&atlas, "coin_anim")

	// Loading borrowed the temp allocator for animation frame lookups
	// and floor tile names; hand it all back in one go before the loop
	// starts.
	free_all(context.temp_allocator)

	for !rl.WindowShouldClose() {
		// --- Update ---
		dt := rl.GetFrameTime()
		sprite_update(&knight, dt)
		sprite_update(&coin, dt)

		// --- Draw --- (back to front: floor, props, then the knight)
		rl.BeginDrawing()
		rl.ClearBackground(BACKGROUND_COLOR)
		for rect, i in floor_tiles {
			col := i % COLS // flat array -> grid coordinates
			row := i / COLS
			dest := rl.Rectangle{f32(col * TILE_SIZE), f32(row * TILE_SIZE),
			                     TILE_SIZE, TILE_SIZE}
			rl.DrawTexturePro(atlas.texture, rect, dest, {0, 0}, 0, rl.WHITE)
		}
		// A closed chest is frame 0 of its opening animation.
		atlas_draw(&atlas, "chest_empty_open_anim_f0",
		           {knight_pos.x - 3 * TILE_SIZE, knight_pos.y + TILE_SIZE},
		           SCALE)
		atlas_draw(&atlas, "skull",
		           {knight_pos.x + 2.5 * TILE_SIZE,
		            knight_pos.y + 1.5 * TILE_SIZE}, SCALE)
		sprite_draw(coin, &atlas,
		            {knight_pos.x - 1.7 * TILE_SIZE,
		             knight_pos.y + 1.3 * TILE_SIZE}, SCALE)
		sprite_draw(knight, &atlas, knight_pos, SCALE)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()
	}
}
