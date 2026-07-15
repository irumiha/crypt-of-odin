// Drop tables and pickup effects: what falls out of a dead enemy, and
// what touching it does to you.
//
// The table takes its dice (an explicit random generator) from the
// caller, the same lesson as the dungeon generator: explicit
// randomness is testable randomness. Rolling is plain
// cumulative-weight selection; balancing the game's economy is
// editing the table at the bottom.

package crypt

import "core:math/rand"

Drop_Entry :: struct {
	kind:   Pickup_Kind,
	weight: i32,
}

Drop_Table :: struct {
	// Weighted outcomes plus a weight for dropping nothing at all.
	// Weights are relative; they don't need to sum to anything neat.
	entries: []Drop_Entry,
	nothing: i32,
}

roll :: proc(t: Drop_Table, rng: rand.Generator) -> (kind: Pickup_Kind,
                                                     dropped: bool) {
	// One roll: walk the cumulative weights, land somewhere. The
	// second return value is the comma-ok convention: false means the roll
	// landed in the "nothing" band.
	total := t.nothing
	for e in t.entries {
		total += e.weight
	}
	pick := 1 + rand.int31_max(total, rng)
	for e in t.entries {
		if pick <= e.weight {
			return e.kind, true
		}
		pick -= e.weight
	}
	return .Coin, false
}

label :: proc(kind: Pickup_Kind) -> string {
	// What the hover UI calls each pickup.
	switch kind {
	case .Coin:   return "coin"
	case .Key:    return "the seal key"
	case .Heart:  return "heart"
	case .Max_Hp: return "heart container"
	case .Power:  return "sword power"
	case .Crown:  return "the crown of Odin"
	}
	return ""
}

apply_pickup :: proc(w: ^World, player: Entity, power: ^i32,
                     kind: Pickup_Kind) {
	// The effect of touching a pickup, for the kinds that change the
	// player. Coins and keys mean something to the caller, not to the
	// knight's body, so they are handled where they're counted.
	switch kind {
	case .Heart:
		h := w.healths[player.idx].max_hp
		w.healths[player.idx].hp = min(w.healths[player.idx].hp + 1, h)
	case .Max_Hp:
		w.healths[player.idx].max_hp += 1
		w.healths[player.idx].hp += 1
	case .Power:
		power^ += 1
	case .Coin, .Key, .Crown:
		// they mean something to the run, not to the knight's body
	}
}

@(rodata)
ENEMY_DROPS := Drop_Table{
	entries = {
		{.Coin, 30},
		{.Heart, 12},
		{.Power, 4},
		{.Max_Hp, 3},
	},
	nothing = 51,
}
