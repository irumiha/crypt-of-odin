// The bestiary: every enemy's base numbers, and how floors scale
// them. Kept in its own file so the numbers are testable headless and
// balancing the game is editing one table.
//
// Odin note: the animation names are spelled out per enemy instead of
// built from `name` at spawn time. Strings built at runtime need an
// owner; strings in a constant table need nobody.

package crypt

Enemy_Stats :: struct {
	name:      string, // atlas base name
	idle_anim: string,
	run_anim:  string,
	hp:        i32,
	speed:     f32, // chase speed, px/s
	aggro:     f32, // start chasing inside this range, px
	scale:     f32, // multiplies SCALE at spawn; 2 for ogre and the boss
}

// The boss's minion of choice: fast, frail. A compile-time constant
// so the @(rodata) table below can include it by name.
IMP :: Enemy_Stats{"imp", "imp_idle_anim", "imp_run_anim", 1, 95, 140, 1}
GOBLIN :: Enemy_Stats{
	"goblin", "goblin_idle_anim", "goblin_run_anim", 2, 85, 150, 1,
}
SKELET :: Enemy_Stats{
	"skelet", "skelet_idle_anim", "skelet_run_anim", 2, 70, 170, 1,
}
CHORT :: Enemy_Stats{
	"chort", "chort_idle_anim", "chort_run_anim", 3, 80, 160, 1,
}
OGRE :: Enemy_Stats{"ogre", "ogre_idle_anim", "ogre_run_anim", 5, 45, 190, 2}

// @(rodata) puts these tables in read-only memory: any accidental
// write should fault, not silently rebalance the game.
@(rodata)
ENEMY_KINDS := [5]Enemy_Stats{
	GOBLIN,
	SKELET,
	IMP,
	CHORT,
	OGRE,
}

// The boss. Slow and huge; the fight's pressure comes from the locked
// room, the contact damage, and the minions, not from outrunning the
// player. Aggro is bigger than the whole room: sensing is room-scoped,
// so stepping into the throne room is starting the fight.
@(rodata)
WARDEN := Enemy_Stats{
	"big_demon", "big_demon_idle_anim", "big_demon_run_anim",
	20, 55, 1000, 2,
}

scaled :: proc(s: Enemy_Stats, floor_num: int) -> Enemy_Stats {
	// Per-floor difficulty: +1 hp every second floor, +8% speed per
	// floor after the first. Gentle on purpose; the knight's own power
	// (hearts, sword flasks) climbs too, and the fun lives in that
	// race staying close.
	out := s
	out.hp = s.hp + i32((floor_num - 1) / 2)
	out.speed = s.speed * (1 + 0.08 * f32(floor_num - 1))
	return out
}
