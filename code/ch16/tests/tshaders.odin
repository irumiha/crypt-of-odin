// Chapter 15: what shader work can be tested without a GPU.
//
// The hover pick is rectangle math, so it gets ordinary tests. The
// shaders themselves are text files with rules we can hold them to:
// every *-330.fs must have a *-100.fs twin, and the twins must declare
// identical uniforms — a uniform added to one dialect and not the
// other is a bug that only the web build would ever report.

package tests

import "core:strings"
import "core:testing"
import crypt "../src"

// #load_directory bakes the shader sources into the test binary at
// compile time, so these tests run from anywhere, GPU or not.
// (A `:=` global, not a `::` constant: the loaded slice has an
// address, which constants don't.)
SHADER_SOURCES := #load_directory("../shaders")

uniforms_of :: proc(src: string, allocator := context.temp_allocator) -> []string {
	// Every uniform declaration, in file order, comments dropped.
	out := make([dynamic]string, allocator)
	rest := src
	for line in strings.split_lines_iterator(&rest) {
		l := strings.trim_space(strings.split(line, "//",
		                                      context.temp_allocator)[0])
		if strings.has_prefix(l, "uniform ") {
			append(&out, l)
		}
	}
	return out[:]
}

source_named :: proc(name: string) -> (string, bool) {
	sources := SHADER_SOURCES
	for f in sources {
		if strings.has_suffix(f.name, name) {
			return string(f.data), true
		}
	}
	return "", false
}

spawn_pickup_at :: proc(w: ^crypt.World, pos: rl_vec) -> crypt.Entity {
	e := crypt.spawn(w, {.Position, .Collider, .Pickup})
	w.positions[e.idx] = pos
	w.colliders[e.idx] = {size = {32, 32}, layer = .Pickup}
	return e
}

rl_vec :: [2]f32

@(test)
hover_finds_the_pickup_under_the_point :: proc(t: ^testing.T) {
	w := crypt.make_world()
	defer crypt.destroy_world(&w)
	a := spawn_pickup_at(&w, {100, 100})
	b := spawn_pickup_at(&w, {200, 100})
	crypt.hover_system(&w, {210, 110})
	testing.expect_value(t, w.hovered, b.idx)
	crypt.hover_system(&w, {110, 110})
	testing.expect_value(t, w.hovered, a.idx)
}

@(test)
empty_space_hovers_nothing :: proc(t: ^testing.T) {
	w := crypt.make_world()
	defer crypt.destroy_world(&w)
	spawn_pickup_at(&w, {100, 100})
	crypt.hover_system(&w, {500, 500})
	testing.expect_value(t, w.hovered, i32(-1))
}

@(test)
non_pickups_are_not_hoverable :: proc(t: ^testing.T) {
	w := crypt.make_world()
	defer crypt.destroy_world(&w)
	// A collider without .Pickup (an enemy, say) must not match.
	e := crypt.spawn(&w, {.Position, .Collider})
	w.positions[e.idx] = {100, 100}
	w.colliders[e.idx] = {size = {32, 32}, layer = .Enemy}
	crypt.hover_system(&w, {110, 110})
	testing.expect_value(t, w.hovered, i32(-1))
}

@(test)
every_330_shader_has_a_100_twin_with_identical_uniforms :: proc(t: ^testing.T) {
	found := 0
	sources := SHADER_SOURCES
	for f in sources {
		if !strings.has_suffix(f.name, "-330.fs") {
			continue
		}
		found += 1
		twin_name, _ := strings.replace(f.name, "-330.fs", "-100.fs", 1,
		                                context.temp_allocator)
		twin, ok := source_named(twin_name)
		testing.expect(t, ok)
		a := uniforms_of(string(f.data))
		b := uniforms_of(twin)
		testing.expect_value(t, len(a), len(b))
		for u, i in a {
			testing.expect_value(t, u, b[i])
		}
	}
	testing.expect_value(t, found, 2) // outline and crt, and a nudge
	                                  // to update this test
}

@(test)
dialect_markers_are_in_place :: proc(t: ^testing.T) {
	sources := SHADER_SOURCES
	for f in sources {
		src := string(f.data)
		if strings.has_suffix(f.name, "-330.fs") {
			testing.expect(t, strings.has_prefix(src, "#version 330"))
		} else if strings.has_suffix(f.name, "-100.fs") {
			testing.expect(t, strings.has_prefix(src, "#version 100"))
			// WebGL 1 requires a default float precision; desktop GL
			// doesn't, so forgetting it here fails only in the browser.
			testing.expect(t, strings.contains(src,
			                                   "precision mediump float;"))
		}
	}
}
