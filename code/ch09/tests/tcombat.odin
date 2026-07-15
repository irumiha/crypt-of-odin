// Headless combat tests: damage, i-frames, knockback, death, and the
// enemy state machine, all through the real systems.

package tests

import "core:testing"
import crypt "../src"

fighter :: proc(w: ^crypt.World, x, y: f32, hp: i32, layer: crypt.Layer,
                hits: crypt.Layer_Set = {}, dmg: i32 = 0) -> crypt.Entity {
	// A 32x32 combatant with health, and contact damage when dmg > 0.
	comps := crypt.Comp_Set{.Position, .Velocity, .Collider, .Health}
	if dmg > 0 {
		comps += {.Contact_Damage}
	}
	e := crypt.spawn(w, comps)
	w.positions[e.idx] = {x, y}
	w.colliders[e.idx] = {size = {32, 32}, layer = layer, hits = hits}
	w.healths[e.idx] = {hp = hp, max_hp = hp, invuln_time = 0.5}
	if dmg > 0 {
		w.contact_damages[e.idx] = {amount = dmg, knockback = 600}
	}
	return e
}

sword_and_victim :: proc(w: ^crypt.World) -> (sword, victim: crypt.Entity) {
	sword = fighter(w, x = 100, y = 100, hp = 1, layer = .Player_Attack,
	                hits = {.Enemy}, dmg = 1)
	victim = fighter(w, x = 110, y = 100, hp = 3, layer = .Enemy)
	return
}

@(test)
contact_damage_lands_once_per_invulnerability_window :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	_, victim := sword_and_victim(&world)
	crypt.contact_system(&world)
	crypt.damage_system(&world)
	testing.expect_value(t, world.healths[victim.idx].hp, i32(2))
	crypt.contact_system(&world)
	crypt.damage_system(&world) // still inside the i-frame window
	testing.expect_value(t, world.healths[victim.idx].hp, i32(2))
	crypt.health_system(&world, 0.6) // window expires
	crypt.contact_system(&world)
	crypt.damage_system(&world)
	testing.expect_value(t, world.healths[victim.idx].hp, i32(1))
}

@(test)
knockback_shoves_the_victim_away_from_the_hit :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	_, victim := sword_and_victim(&world)
	crypt.contact_system(&world)
	crypt.damage_system(&world)
	testing.expect(t, world.velocities[victim.idx].x > 0) // attacker is left
	testing.expect(t, world.healths[victim.idx].stun > 0)
}

@(test)
death_system_buries_the_dead_and_reports_where :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	_, victim := sword_and_victim(&world)
	world.healths[victim.idx].hp = 1
	crypt.contact_system(&world)
	crypt.damage_system(&world)
	fallen := crypt.death_system(&world)
	testing.expect_value(t, len(fallen), 1)
	testing.expect_value(t, fallen[0].x, f32(110))
	testing.expect(t, !crypt.alive(&world, victim))
}

chase_pair :: proc(w: ^crypt.World) -> (player, enemy: crypt.Entity) {
	player = crypt.spawn(w, {.Position, .Player})
	w.positions[player.idx] = {50, 0}
	enemy = crypt.spawn(w, {.Position, .Velocity, .Ai})
	w.ais[enemy.idx] = {chase_speed = 100, aggro = 100}
	return
}

@(test)
wander_flips_to_chase_inside_aggro_range_and_steers :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	player, enemy := chase_pair(&world)
	crypt.ai_system(&world, player)
	testing.expect_value(t, world.ais[enemy.idx].state, crypt.Ai_State.Chase)
	testing.expect(t, world.velocities[enemy.idx].x > 0) // toward the player
}

@(test)
chase_gives_up_beyond_the_slack_boundary_not_at_it :: proc(t: ^testing.T) {
	world := crypt.make_world()
	defer crypt.destroy_world(&world)
	player, enemy := chase_pair(&world)
	crypt.ai_system(&world, player) // now chasing
	world.positions[player.idx].x = 130 // past aggro, inside slack
	crypt.ai_system(&world, player)
	testing.expect_value(t, world.ais[enemy.idx].state,
	                     crypt.Ai_State.Chase) // hysteresis holds it
	world.positions[player.idx].x = 500 // decisively gone
	crypt.ai_system(&world, player)
	testing.expect_value(t, world.ais[enemy.idx].state,
	                     crypt.Ai_State.Wander)
}
