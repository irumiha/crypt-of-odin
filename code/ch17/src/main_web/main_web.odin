// The web entry point: no loop here either — the browser owns it.
// index.html (generated from index_template.html) calls these
// exported procs: main_start once, main_update per animation frame,
// main_end if the update ever says stop.
//
// Adapted from Karl Zylinski's odin-raylib-web template (MIT).

package main_web

import "base:runtime"
import "core:c"
import "core:mem"
import crypt ".."

@(private = "file")
web_context: runtime.Context

@(export)
main_start :: proc "c" () {
	context = runtime.default_context()

	// Odin's own WASM allocator conflicts with emscripten's memory
	// management, so route every allocation through emscripten's
	// malloc family instead.
	context.allocator = emscripten_allocator()
	runtime.init_global_temporary_allocator(1 * mem.Megabyte)
	context.logger = create_emscripten_logger()

	web_context = context

	crypt.game_init()
}

@(export)
main_update :: proc "c" () -> bool {
	context = web_context
	crypt.game_update()
	return crypt.game_should_run()
}

@(export)
main_end :: proc "c" () {
	context = web_context
	crypt.game_shutdown()
}

@(export)
web_window_size_changed :: proc "c" (w: c.int, h: c.int) {
	context = web_context
	crypt.parent_window_size_changed(int(w), int(h))
}
