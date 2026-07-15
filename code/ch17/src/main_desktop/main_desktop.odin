// The desktop entry point: own the loop, drive the game API. The web
// build (main_web) calls the same three procs; neither knows about
// the other and the game knows about neither.

package main_desktop

import "core:os"
import crypt ".."

main :: proc() {
	// Run from wherever; assets resolve relative to the executable.
	// Asking the OS (not args[0], which is just the command name when
	// launched via PATH) gets the real location.
	if exe_dir, err := os.get_executable_directory(context.temp_allocator);
	   err == nil {
		os.set_working_directory(exe_dir)
	}

	crypt.game_init()
	for crypt.game_should_run() {
		crypt.game_update()
	}
	crypt.game_shutdown()
}
