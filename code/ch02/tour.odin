// The Chapter 2 language tour. Pure Odin, no raylib.
// Run it with:  odin run tour.odin -file
// Every snippet in the chapter lives here; vandalize freely.
package tour

import "core:fmt"

// --- Constants and procs live at file scope ------------------------------

MAX_FLOORS :: 8 // compile-time, baked into the binary

health_color :: proc(fraction: f32) -> string {
	// A condition-only switch replaces if/elif chains; cases are
	// checked top to bottom, first match wins.
	switch {
	case fraction > 0.5:
		return "green"
	case fraction > 0.2:
		return "yellow"
	}
	return "red"
}

quote :: proc(s: string, mark := "\"") -> string {
	// Default parameter values, and tprintf: printf into the
	// temp allocator (more on allocators when the game needs one).
	return fmt.tprintf("%s%s%s", mark, s, mark)
}

// --- Structs are values ----------------------------------------------------

Potion :: struct {
	name:  string,
	doses: int,
}

drink :: proc(p: ^Potion) {
	// A pointer parameter: mutation, but visible at every call site.
	if p.doses > 0 do p.doses -= 1
}

Party_Chest :: struct {
	gold: int,
}

// --- Enums, bit_sets, and exhaustive switch --------------------------------

Element :: enum {
	Fire, Frost, Poison, Holy,
}

verb :: proc(e: Element) -> string {
	switch e { // no default branch: the compiler checks
	case .Fire:   return "burns" // that every Element is handled
	case .Frost:  return "chills"
	case .Poison: return "stacks"
	case .Holy:   return "smites"
	}
	return "" // unreachable, but every path must return something
}

// --- Unions: one type, several shapes ---------------------------------------

Coins :: struct {
	amount: int,
}
Weapon :: struct {
	name:   string,
	damage: int,
}
Loot :: union {
	Coins,
	Weapon,
}

describe :: proc(loot: Loot) -> string {
	switch l in loot { // the compiler guards which fields you can touch
	case Coins:
		return fmt.tprintf("%d coins", l.amount)
	case Weapon:
		return fmt.tprintf("%s (%d dmg)", l.name, l.damage)
	}
	return "nothing" // a union can also hold nil: an empty chest
}

// --- Generics, briefly -------------------------------------------------------

last_or :: proc(s: []$T, fallback: T) -> T {
	// $T is filled in at compile time, per call site.
	return s[len(s) - 1] if len(s) > 0 else fallback
}

main :: proc() {
	// --- Bindings: constants and variables --------------------------------
	player_name := "Odin" // inferred as string; the type is static
	gold := 0
	gold += 30
	// Types are inferred, but present and static. This does not compile:
	// gold = "thirty"

	// --- Calls, named arguments, if-as-expression --------------------------
	fmt.println(health_color(0.7))        // green
	fmt.println(quote(health_color(0.7))) // "green"
	fmt.println(quote("ow", mark = "!"))  // !ow!
	mood := "optimistic" if gold > 0 else "filing a ticket"
	fmt.println(mood) // optimistic

	// --- Objects are values -------------------------------------------------
	mine := Potion{name = "healing", doses = 3}
	yours := mine // a copy. A real one. The whole potion.
	yours.doses = 0
	fmt.println(mine.doses) // 3 — your drinking problem, not mine
	drink(&mine)            // taking the address is the permission slip
	fmt.println(mine.doses) // 2

	// --- Pointers share, like Java references always do ---------------------
	chest := new(Party_Chest) // one chest, on the heap
	defer free(chest)         // and the promise to clean it up, up front
	chest.gold = 100
	same_chest := chest // same chest, second handle
	same_chest.gold -= 60
	fmt.println(chest.gold) // 40 — sharing is explicit, and it's the exception

	// --- Enums and bit_sets --------------------------------------------------
	resists: bit_set[Element] = {.Frost, .Holy} // one bit per value
	fmt.println(.Poison in resists) // false
	fmt.println(verb(.Frost))       // chills

	// --- Dynamic arrays and maps ----------------------------------------------
	inventory: [dynamic]string
	defer delete(inventory)
	append(&inventory, "sword", "rope", "lantern")
	fmt.println(len(inventory))                // 3
	fmt.println(inventory[len(inventory) - 1]) // lantern

	prices: map[string]int // a zero-value map is ready to use
	defer delete(prices)
	prices["sword"] = 50
	prices["rope"] = 3
	prices["lantern"] = 12
	fmt.println(prices["shield"]) // 0 — a missing key is the zero value...
	price, found := prices["shield"]
	fmt.println(price, found) // 0 false — ...and comma-ok tells you why

	// --- Loops do what iterators did -------------------------------------------
	for n in 1 ..= 3 {
		fmt.printfln("floor %d of %d", n, 3)
	}
	damage := [3]int{10, 12, 7} // a fixed array: on the stack, no allocation
	for &d in damage { // &d is a reference into the array — no index bookkeeping
		d *= 2
	}
	fmt.println(damage) // [20, 24, 14]

	// --- Unions in action ---------------------------------------------------------
	fmt.println(describe(Coins{amount = 42}))               // 42 coins
	fmt.println(describe(Weapon{name = "axe", damage = 7})) // axe (7 dmg)

	// --- Generics resolved at compile time -----------------------------------------
	fmt.println(last_or([]int{3, 1, 4}, 0))   // 4
	fmt.println(last_or([]string{}, "empty")) // empty

	fmt.printfln("%s leaves with %d gold across %d floors",
	             player_name, gold, MAX_FLOORS)
}
