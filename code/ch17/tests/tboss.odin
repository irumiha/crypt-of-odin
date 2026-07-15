// Chapter 16: the boss and the run, tested headless. The phase flip,
// the minion cadence, the difficulty curve, and the final floor's
// shape are all arithmetic; the fight itself is the playtester's.

package tests

import "core:testing"
import crypt "../src"

make_warden :: proc(w: ^crypt.World) -> crypt.Entity {
	e := crypt.spawn(w, {.Boss, .Health, .Ai, .Position})
	w.healths[e.idx] = {hp = 20, max_hp = 20}
	w.ais[e.idx] = {chase_speed = 55, aggro = 420}
	return e
}

@(test)
floor_one_is_the_table_verbatim :: proc(t: ^testing.T) {
	for s in crypt.ENEMY_KINDS {
		testing.expect_value(t, crypt.scaled(s, 1), s)
	}
}

@(test)
floor_three_plus_one_hp_16_percent_faster :: proc(t: ^testing.T) {
	g := crypt.scaled(crypt.ENEMY_KINDS[0], 3)
	testing.expect_value(t, g.hp, crypt.ENEMY_KINDS[0].hp + 1)
	testing.expect(t, abs(g.speed - crypt.ENEMY_KINDS[0].speed * 1.16) < 0.001)
}

@(test)
deeper_floors_never_get_easier :: proc(t: ^testing.T) {
	for floor in 1 ..= 9 {
		a := crypt.scaled(crypt.IMP, floor)
		b := crypt.scaled(crypt.IMP, floor + 1)
		testing.expect(t, b.hp >= a.hp)
		testing.expect(t, b.speed >= a.speed)
	}
}

@(test)
healthy_boss_stalks_and_calls_nobody :: proc(t: ^testing.T) {
	w := crypt.make_world()
	defer crypt.destroy_world(&w)
	b := make_warden(&w)
	for _ in 0 ..< 10 {
		testing.expect_value(t, len(crypt.boss_system(&w, 0.5)), 0)
	}
	testing.expect_value(t, w.bosses[b.idx].phase, crypt.Boss_Phase.Stalk)
}

@(test)
half_health_enrages_once_and_speeds_the_chase :: proc(t: ^testing.T) {
	w := crypt.make_world()
	defer crypt.destroy_world(&w)
	b := make_warden(&w)
	w.healths[b.idx].hp = 10
	crypt.boss_system(&w, 0.016)
	testing.expect_value(t, w.bosses[b.idx].phase, crypt.Boss_Phase.Enrage)
	testing.expect(t, abs(w.ais[b.idx].chase_speed - 55 * 1.6) < 0.001)
	crypt.boss_system(&w, 0.016)
	testing.expect(t, abs(w.ais[b.idx].chase_speed - 55 * 1.6) < 0.001) // no double dip
}

@(test)
an_enraged_boss_calls_minions_on_a_cadence :: proc(t: ^testing.T) {
	w := crypt.make_world()
	defer crypt.destroy_world(&w)
	b := make_warden(&w)
	w.healths[b.idx].hp = 1
	testing.expect_value(t, len(crypt.boss_system(&w, 0.016)), 0) // the flip frame only flips
	testing.expect_value(t, len(crypt.boss_system(&w, 0.016)), 1) // the first call comes at once
	testing.expect_value(t, len(crypt.boss_system(&w, 1.0)), 0)
	testing.expect_value(t, len(crypt.boss_system(&w, 3.0)), 1) // the 3.5 s cadence
	testing.expect_value(t, len(crypt.boss_system(&w, 0.1)), 0)
}

@(test)
find_boss_sees_the_boss_and_only_while_it_lives :: proc(t: ^testing.T) {
	w := crypt.make_world()
	defer crypt.destroy_world(&w)
	testing.expect_value(t, crypt.find_boss(&w), i32(-1))
	b := make_warden(&w)
	testing.expect_value(t, crypt.find_boss(&w), b.idx)
	crypt.despawn(&w, b)
	testing.expect_value(t, crypt.find_boss(&w), i32(-1))
}

@(test)
no_stairs_anywhere_and_the_throne_room_is_sealed :: proc(t: ^testing.T) {
	d := crypt.generate(20260714, 3, final = true)
	defer crypt.destroy_dungeon(&d)
	for y in i32(0) ..< i32(crypt.ROOM_ROWS * crypt.ROOM_H) {
		for x in i32(0) ..< i32(crypt.ROOM_COLS * crypt.ROOM_W) {
			testing.expect(t, crypt.tile_at(d.tilemap, x, y) != .Stairs)
		}
	}
	testing.expect(t, crypt.is_locked(d))
}

@(test)
seals_dissolve_then_slam_shut_again :: proc(t: ^testing.T) {
	d := crypt.generate(99, 3, final = true)
	defer crypt.destroy_dungeon(&d)
	testing.expect(t, crypt.is_locked(d))
	crypt.unlock(&d)
	testing.expect(t, !crypt.is_locked(d))
	crypt.relock(&d)
	testing.expect(t, crypt.is_locked(d))
	crypt.unlock(&d) // the Warden falls; out you go
	testing.expect(t, !crypt.is_locked(d))
}

@(test)
inside_room_knows_the_interior_from_the_doorway :: proc(t: ^testing.T) {
	d := crypt.generate(7, 3, final = true)
	defer crypt.destroy_dungeon(&d)
	testing.expect(t, crypt.inside_room(d, d.stairs_room,
	                                    crypt.room_center(d, d.stairs_room)))
	// A point on the room's border wall column is not "well inside".
	r := d.rooms[d.stairs_room]
	doorway := [2]f32{
		f32(r.gx * crypt.ROOM_W * crypt.TILE_SIZE),
		f32(r.gy * crypt.ROOM_H * crypt.TILE_SIZE) +
		crypt.ROOM_H * crypt.TILE_SIZE / 2,
	}
	testing.expect(t, !crypt.inside_room(d, d.stairs_room, doorway))
}

@(test)
the_crown_has_a_name_for_the_hover_ui :: proc(t: ^testing.T) {
	testing.expect_value(t, crypt.label(.Crown), "the crown of Odin")
}
