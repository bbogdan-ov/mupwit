package main_hotreload

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"

import "../common"

//
// Loads mupwit.so/.dll/.dynlib dynamic library and reloads it at any given
// time without closing the app! The dynamic library obviously needs to be
// recompiled after any change and only then you can reload it by pressing Ctrl-R.
//
// And you don't even need a stinky scripting language for that!!
//
// You only have to reopen the app when the size of `mupwit.State` or
// `ui.State` changes, but you'll be warned whenever this happens.
//
// Thanks to Karl Zylinski and his hot-reload template!
//     https://github.com/karl-zylinski/odin-raylib-hot-reload-game-template
//

DLL_EXT :: ".so"
DLL_PATH :: "build/mupwit"

API :: struct {
	init:           proc(),
	destroy:        proc(),
	should_run:     proc() -> bool,
	should_reload:  proc() -> bool,
	get_state:      proc() -> rawptr,
	get_state_size: proc() -> int,
	on_reloaded:    proc(state: rawptr),

	// Library handle.
	__handle:       dynlib.Library,
	dll_path:       string,
	version:        int,
}

main :: proc() {
	context.logger = common.make_logger()

	// Setup tracking allocator.
	track := common.make_tracking_allocator(context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer common.tracking_allocator_report_and_destroy(&track)

	// Intial dynamic library load.
	api, ok := load_api(0)
	if !ok do os.exit(1)

	apis_to_unload := make([dynamic]API)

	api.init()

	for api.should_run() {
		if api.should_reload() {
			runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

			log.info("HOTRELOAD: Reloading...")
			new_api := load_api(api.version) or_continue

			if api.get_state_size() != new_api.get_state_size() {
				log.warn("HOTRELOAD: Size of the state changed, recompiler and re-run the app")
				unload_api(new_api)
				break
			}

			// Still not sure why, but i shouldn't unload previous library
			// handles right away, but only at the end of the program.
			append(&apis_to_unload, api)

			state := api.get_state()
			api = new_api
			api.on_reloaded(state)
		}
	}

	api.destroy()

	// Clean up.
	log.info("HOTRELOAD: Cleaning up DLLs...")

	append(&apis_to_unload, api)
	for api in apis_to_unload {
		unload_api(api)
	}
	delete(apis_to_unload)

	log.info("HOTRELOAD: Bye")
}

load_api :: proc(prev_version: int) -> (api: API, ok: bool) {
	api.version = prev_version + 1

	ORIG_DLL_PATH :: DLL_PATH + DLL_EXT
	api.dll_path = fmt.aprintf(DLL_PATH + "-%d" + DLL_EXT, api.version)

	// Copy original DLL so it doesn't get locked and compiler could write
	// to it when compiling.
	copy_err := os.copy_file(api.dll_path, ORIG_DLL_PATH)
	if copy_err != nil {
		log.errorf("HOTRELOAD: Failed to copy %q to %q: %v", ORIG_DLL_PATH, api.dll_path, copy_err)
		return api, false
	}

	_, ok = dynlib.initialize_symbols(&api, api.dll_path)
	if !ok {
		err := dynlib.last_error()
		log.errorf("HOTRELOAD: Failed to load the dynamic library %q: %v", api.dll_path, err)

		os.remove(api.dll_path)
		return api, false
	}

	log.infof("HOTRELOAD: Loaded the dynamic library %q", api.dll_path)

	return api, true
}

unload_api :: proc(api: API) {
	os.remove(api.dll_path)
	delete(api.dll_path)
	dynlib.unload_library(api.__handle)
}
