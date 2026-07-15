// Headless tests for the drop table and pickup effects. The table
// takes explicit dice, so its statistics are reproducible enough to
// assert against.

package tests

import "core:math/rand"
import "core:testing"
import crypt "../src"

@(test)
weights_are_honored_over_many_rolls_nothing_included :: proc(t: ^testing.T) {
	state := rand.create(1234)
	rng := rand.default_random_generator(&state)
	counts: [crypt.Pickup_Kind]int
	nothing := 0
	for _ in 0 ..< 10_000 {
		if kind, dropped := crypt.roll(crypt.ENEMY_DROPS, rng); dropped {
			counts[kind] += 1
		} else {
			nothing += 1
		}
	}
	// Total weight is 100, so weights read as percentages. Allow
	// generous slack; this asserts the shape, not the decimals.
	testing.expect(t, nothing >= 4_500 && nothing <= 5_700)          // 51
	testing.expect(t, counts[.Coin] >= 2_500 && counts[.Coin] <= 3_500) // 30
	testing.expect(t, counts[.Heart] >= 800 && counts[.Heart] <= 1_600) // 12
	testing.expect(t, counts[.Power] >= 200 && counts[.Power] <= 700)   // 4
	testing.expect(t, counts[.Max_Hp] >= 100 && counts[.Max_Hp] <= 600) // 3
	testing.expect_value(t, counts[.Key], 0) // keys never drop
}

@(test)
the_same_dice_roll_the_same_drops :: proc(t: ^testing.T) {
	state_a := rand.create(7)
	rng_a := rand.default_random_generator(&state_a)
	state_b := rand.create(7)
	rng_b := rand.default_random_generator(&state_b)
	for _ in 0 ..< 100 {
		kind_a, dropped_a := crypt.roll(crypt.ENEMY_DROPS, rng_a)
		kind_b, dropped_b := crypt.roll(crypt.ENEMY_DROPS, rng_b)
		testing.expect_value(t, dropped_a, dropped_b)
		testing.expect_value(t, kind_a, kind_b)
	}
}

healer :: proc(w: ^crypt.World) -> crypt.Entity {
	player := crypt.spawn(w, {.Position, .Player, .Health})
	w.healths[player.idx] = {hp = 3, max_hp = 6}
	return player
}

@(test)
a_heart_heals_one_and_never_past_max :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	player := healer(&world)
	power: i32 = 1
	crypt.apply_pickup(&world, player, &power, .Heart)
	testing.expect_value(t, world.healths[player.idx].hp, i32(4))
	world.healths[player.idx].hp = 6
	crypt.apply_pickup(&world, player, &power, .Heart)
	testing.expect_value(t, world.healths[player.idx].hp, i32(6)) // full
}

@(test)
the_blue_flask_raises_the_ceiling_and_fills_the_gap_it_made :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	player := healer(&world)
	power: i32 = 1
	crypt.apply_pickup(&world, player, &power, .Max_Hp)
	testing.expect_value(t, world.healths[player.idx].max_hp, i32(7))
	testing.expect_value(t, world.healths[player.idx].hp, i32(4))
}

@(test)
the_green_flask_sharpens_the_sword :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	player := healer(&world)
	power: i32 = 1
	crypt.apply_pickup(&world, player, &power, .Power)
	testing.expect_value(t, power, i32(2))
}
