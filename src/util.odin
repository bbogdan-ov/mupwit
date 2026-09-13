package mupwit

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:time"

make_default_context :: proc "contextless" () -> runtime.Context {
	c := runtime.default_context()
	c.logger = make_logger()
	return c
}

make_logger :: proc "contextless" () -> log.Logger {
	return log.Logger{procedure = _logger_proc}
}

@(private)
_logger_proc :: proc(
	data: rawptr,
	level: log.Level,
	text: string,
	options: log.Options,
	location := #caller_location,
) {
	fmt.print("\e[37m")

	h, m, s, nanos := time.precise_clock(time.now())
	fmt.printf("%02d:%02d:%02d.%03d ", h, m, s, nanos / 1_000_000)

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

	fmt.println(text)
}
