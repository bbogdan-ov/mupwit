package mupwit

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:sync"
import "core:time"

// ------------------------------
// Sync.
// ------------------------------

Mutex :: struct($T: typeid) {
	_v:     T,
	_mutex: sync.Mutex,
}

mutex_lock :: proc(mutex: ^Mutex($T)) -> ^T {
	sync.lock(&mutex._mutex)
	return &mutex._v
}
mutex_unlock :: proc(mutex: ^Mutex($T)) {
	sync.unlock(&mutex._mutex)
}

// ------------------------------
// Misc.
// ------------------------------

make_tracking_allocator :: proc(allocator := context.allocator) -> mem.Tracking_Allocator {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, allocator)
	return track
}

tracking_allocator_report_and_destroy :: proc(track: ^mem.Tracking_Allocator) {
	if len(track.allocation_map) > 0 {
		fmt.println("------------------------------")
		for _, leak in track.allocation_map {
			fmt.printfln("LEAK: %v bytes", leak.location, leak.size)
		}
	}

	mem.tracking_allocator_destroy(track)
}

make_default_context :: proc "contextless" () -> runtime.Context {
	c := runtime.default_context()
	c.logger = make_logger()
	return c
}

make_logger :: proc "contextless" () -> log.Logger {
	opts: log.Options
	if os.is_tty(os.stdout) {
		opts += {.Terminal_Color}
	}
	return log.Logger{procedure = _logger_proc, options = opts}
}

@(private)
_logger_proc :: proc(
	data: rawptr,
	level: log.Level,
	text: string,
	options: log.Options,
	location := #caller_location,
) {
	if .Terminal_Color in options {
		fmt.print("\e[37m")
	}

	h, m, s, nanos := time.precise_clock(time.now())
	fmt.printf("%02d:%02d:%02d.%03d ", h, m, s, nanos / 1_000_000)

	if .Terminal_Color in options {
		switch level {
		case .Debug:
			fmt.print("\e[37mDEBUG:\e[0m ")
		case .Info:
			fmt.print("\e[94mINFO:\e[0m ")
		case .Warning:
			fmt.printf("(%s:%d) ", location.file_path, location.line)
			fmt.print("\e[93mWARN:\e[0m ")
		case .Error:
			fmt.printf("(%s:%d) ", location.file_path, location.line)
			fmt.print("\e[91mERROR:\e[0m ")
		case .Fatal:
			fmt.printf("(%s:%d) ", location.file_path, location.line)
			fmt.print("\e[91;7mFATAL:\e[0m ")
		}
	} else {
		switch level {
		case .Debug:
			fmt.print("DEBUG: ")
		case .Info:
			fmt.print("INFO: ")
		case .Warning:
			fmt.printf("(%s:%d) ", location.file_path, location.line)
			fmt.print("WARN: ")
		case .Error:
			fmt.printf("(%s:%d) ", location.file_path, location.line)
			fmt.print("ERROR: ")
		case .Fatal:
			fmt.printf("(%s:%d) ", location.file_path, location.line)
			fmt.print("FATAL: ")
		}
	}

	fmt.println(text)
}
