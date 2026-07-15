// The game's entity-component-system, all of it.
//
// An entity is a slot index plus a generation. Components are columns:
// one dynamic array per component type, all the same length, with a
// per-slot bit_set mask saying which columns apply. Queries scan the
// masks. Deliberately not generic and not a library; it knows this
// game's components by name, and adding one is a three-line diff.

package crypt

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

Comp_Kind :: enum {
	Position, Velocity, Sprite, Lifetime,
}

Comp_Set :: bit_set[Comp_Kind]

Entity :: struct {
	// A typed handle: a slot index plus the generation it was issued
	// in. If the slot has been despawned and reused since, the
	// generations no longer match and the handle is stale (see alive).
	idx: i32,
	gen: u32,
}

World :: struct {
	masks:      [dynamic]Comp_Set, // which components each slot has
	gens:       [dynamic]u32,      // bumped every time a slot is reused
	free_slots: [dynamic]i32,
	// One array per component, all the same length. A slot owns row
	// idx in every one of them; the mask says which rows are
	// meaningful.
	positions:  [dynamic]rl.Vector2,
	velocities: [dynamic]rl.Vector2,
	sprites:    [dynamic]Anim_Sprite,
	lifetimes:  [dynamic]f32,
}

make_world :: proc() -> World {
	// Nothing in here needs a non-zero start yet; the constructor
	// exists so destroy_world has a twin, and so later chapters have
	// exactly one place to put a default.
	return {}
}

destroy_world :: proc(w: ^World) {
	// Returns every column to the allocator. Odin's deal: you see the
	// whole cleanup, and it is one delete per field, no destructor
	// magic. Sprites hold atlas-owned slices, so nothing deeper owns
	// memory of its own.
	delete(w.masks); delete(w.gens); delete(w.free_slots)
	delete(w.positions); delete(w.velocities); delete(w.sprites)
	delete(w.lifetimes)
}

alive :: proc(w: ^World, e: Entity) -> bool {
	// True while the handle still refers to the entity it was issued
	// for. A despawned (or despawned-and-reused) slot fails the
	// generation check, so stale handles read as dead instead of
	// pointing at whoever lives there now.
	return e.idx >= 0 && e.idx < i32(len(w.gens)) && w.gens[e.idx] == e.gen
}

entity :: proc(w: ^World, idx: i32) -> Entity {
	// The current handle for a slot index (used inside systems, where
	// queries yield raw indices).
	return {idx = idx, gen = w.gens[idx]}
}

entity_count :: proc(w: ^World) -> int {
	// Live entities right now (allocated slots minus the free list).
	return len(w.masks) - len(w.free_slots)
}

spawn :: proc(w: ^World, comps: Comp_Set) -> Entity {
	// Claims a slot (reusing a despawned one when available), stamps
	// it with the component mask, and returns its handle. Component
	// data starts at the zero value either way: a reused slot is
	// scrubbed of its previous tenant, so a caller that skips a column
	// gets zeroes, never a ghost.
	idx: i32
	if len(w.free_slots) > 0 {
		idx = pop(&w.free_slots)
		w.positions[idx] = {}
		w.velocities[idx] = {}
		w.sprites[idx] = {}
		w.lifetimes[idx] = 0
	} else {
		idx = i32(len(w.masks))
		append(&w.masks, Comp_Set{})
		append(&w.gens, 0)
		append(&w.positions, rl.Vector2{})
		append(&w.velocities, rl.Vector2{})
		append(&w.sprites, Anim_Sprite{})
		append(&w.lifetimes, 0)
	}
	w.masks[idx] = comps
	return {idx = idx, gen = w.gens[idx]}
}

despawn :: proc(w: ^World, e: Entity) {
	// Retires an entity: clears its mask, invalidates every existing
	// handle to it, and files the slot for reuse. The component data
	// is left in place, unreachable, until the next tenant overwrites
	// it. Never call this while walking a query's results you also
	// mutate; collect first (see lifetime_system for the pattern).
	if alive(w, e) {
		w.masks[e.idx] = {}
		w.gens[e.idx] += 1 // every old handle to this slot goes stale
		append(&w.free_slots, e.idx)
	}
}

query :: proc(w: ^World, comps: Comp_Set,
              allocator := context.temp_allocator) -> []i32 {
	// Every live slot that has at least the requested components.
	// `<=` is the bit_set subset test: one AND and one compare per
	// slot. Dead slots have mask {} and never match. Scans every slot
	// ever allocated, which at this game's scale is nanoseconds; the
	// result lives on the temp allocator and dies with the frame.
	out := make([dynamic]i32, 0, len(w.masks), allocator)
	for m, i in w.masks {
		if comps <= m {
			append(&out, i32(i))
		}
	}
	return out[:]
}

dump :: proc(w: ^World, e: Entity,
             allocator := context.temp_allocator) -> string {
	// The whole entity, reassembled for inspection: the answer to "ECS
	// smears my entity across four arrays." Keep this current as
	// components get added; it is the debugging tool this architecture
	// owes you.
	if !alive(w, e) {
		return fmt.aprintf("entity %d: dead (stale handle, gen %d)",
		                   e.idx, e.gen, allocator = allocator)
	}
	b := strings.builder_make(allocator)
	fmt.sbprintf(&b, "entity %d (gen %d)", e.idx, e.gen)
	m := w.masks[e.idx]
	if .Position in m {
		p := w.positions[e.idx]
		fmt.sbprintf(&b, "\n  position  (%.1f, %.1f)", p.x, p.y)
	}
	if .Velocity in m {
		v := w.velocities[e.idx]
		fmt.sbprintf(&b, "\n  velocity  (%.1f, %.1f)", v.x, v.y)
	}
	if .Sprite in m {
		fmt.sbprintf(&b, "\n  sprite    %dx%d px on screen",
		             int(sprite_width(w.sprites[e.idx])),
		             int(sprite_height(w.sprites[e.idx])))
	}
	if .Lifetime in m {
		fmt.sbprintf(&b, "\n  lifetime  %.2fs left", w.lifetimes[e.idx])
	}
	return strings.to_string(b)
}
