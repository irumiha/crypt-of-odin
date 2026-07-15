// The HUD: everything drawn on the glass rather than in the world
// (hearts, the purse, the minimap), plus one world-space guest, the
// floating damage numbers. Screen-space procs are called after
// EndMode2D; draw_floating_texts is called inside the camera block.

package crypt

import "core:fmt"
import rl "vendor:raylib"

draw_icon_stat :: proc(atlas: ^Atlas, icon: string, x, y: i32,
                       value: cstring, color: rl.Color) {
	// A small atlas icon (scaled to 24 px tall, aspect kept) with a
	// number next to it. The whole HUD is variations of this.
	src := atlas_rect(atlas, icon)
	h := f32(24)
	w := src.width * h / src.height
	rl.DrawTexturePro(atlas.texture, src,
	                  {f32(x), f32(y), w, h}, {0, 0}, 0, rl.WHITE)
	rl.DrawText(value, x + i32(w) + 6, y + 2, 20, color)
}

draw_hearts :: proc(atlas: ^Atlas, hp, max_hp: i32) {
	// One heart per max hit point, full or empty. Icons over numerals:
	// you can read hearts from the corner of an eye mid-dodge. Past a
	// dozen the row would march into the minimap, so a dedicated
	// flask farmer graduates to a numeral instead.
	full := atlas_rect(atlas, "ui_heart_full")
	empty := atlas_rect(atlas, "ui_heart_empty")
	shown := min(max_hp, 12)
	for i in 0 ..< shown {
		src := full if i < hp else empty
		rl.DrawTexturePro(atlas.texture, src,
		                  {f32(10 + i * 30), 34, 26, 24},
		                  {0, 0}, 0, rl.WHITE)
	}
	if max_hp > 12 {
		rl.DrawText(fmt.ctprintf("%d/%d", hp, max_hp),
		            10 + shown * 30 + 4, 36, 20, rl.RAYWHITE)
	}
}

draw_minimap :: proc(d: Dungeon, current: int, screen_w: i32) {
	// The floor graph as it is: one small rectangle per room, in grid
	// positions, top-right. Gold is the sealed stairs room (green once
	// open); the outlined cell is where you are.
	CW :: 22
	CH :: 13
	PAD :: 3
	ox := screen_w - ROOM_COLS * (CW + PAD) - 10
	oy := i32(10)
	for r, i in d.rooms {
		x := ox + r.gx * (CW + PAD)
		y := oy + r.gy * (CH + PAD)
		color: rl.Color
		if i == d.stairs_room && is_locked(d) {
			color = rl.GOLD
		} else if i == d.stairs_room {
			color = rl.GREEN
		} else {
			color = {90, 85, 110, 255}
		}
		rl.DrawRectangle(x, y, CW, CH, color)
		if i == current {
			rl.DrawRectangleLinesEx({f32(x), f32(y), CW, CH}, 2,
			                        rl.RAYWHITE)
		}
	}
}

draw_hud :: proc(atlas: ^Atlas, d: Dungeon, current: int, hp: Health,
                 coins: int, power: i32, floor_num: int, screen_w: i32) {
	// The whole screen-space layer, one call in the main loop.
	draw_hearts(atlas, hp.hp, hp.max_hp)
	draw_icon_stat(atlas, "coin_anim_f0", 10, 66,
	               fmt.ctprintf("%d", coins), rl.GOLD)
	draw_icon_stat(atlas, "weapon_knight_sword", 90, 66,
	               fmt.ctprintf("%d", power), rl.GREEN)
	draw_icon_stat(atlas, "floor_stairs", 10, 96,
	               fmt.ctprintf("floor %d", floor_num), rl.LIGHTGRAY)
	draw_icon_stat(atlas, "flask_big_yellow", 130, 96,
	               "sealed" if is_locked(d) else "open",
	               rl.GOLD if is_locked(d) else rl.GREEN)
	draw_minimap(d, current, screen_w)
}

draw_boss_bar :: proc(name: cstring, hp, max_hp: i32,
                      screen_w, screen_h: i32) {
	// The classic bottom-of-screen boss health bar: it appears when
	// the fight starts and its length is the fight's progress. Screen
	// space; call it after EndMode2D, when the boss is alive and the
	// player is in its room.
	W :: 300
	H :: 10
	x := (screen_w - W) / 2
	y := screen_h - 34
	rl.DrawText(name, (screen_w - rl.MeasureText(name, 16)) / 2, y - 20,
	            16, {220, 60, 60, 255})
	rl.DrawRectangle(x - 2, y - 2, W + 4, H + 4, {0, 0, 0, 180})
	rl.DrawRectangle(x, y, W * hp / max(1, max_hp), H,
	                 {200, 40, 40, 255})
}

draw_floating_texts :: proc(w: ^World) {
	// World-space damage numbers: call inside BeginMode2D. They fade
	// out over their lifetime and drift on their own velocity.
	for i in query(w, {.Position, .Float_Text, .Lifetime}) {
		alpha := u8(255 * clamp(w.lifetimes[i] / 0.7, 0, 1))
		rl.DrawText(fmt.ctprintf("%d", w.float_texts[i]),
		            i32(w.positions[i].x), i32(w.positions[i].y), 16,
		            {255, 240, 200, alpha})
	}
}
