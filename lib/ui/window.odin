package ui

import "base:runtime"
import "core:log"
import "core:math"
import "core:os"
import "core:time"
import rlgl "rlgl"
import glfw_ "vendor:glfw"
import glfw "vendor:glfw/bindings"

TARGET_FPS :: 120

Window :: struct #all_or_none {
	ready:            bool,
	handle:           glfw.WindowHandle,
	width:            f32,
	height:           f32,

	// Mouse position
	mouse:            Point,
	// Mouse wheel movement
	wheel:            Point,

	// Time elapsed since the last frame in milliseconds.
	delta:            u32,
	_start_time:      time.Time,

	// Text truncation
	text_trunc_width: f32,
	text_trunc_x:     f32,

	// Arena allocator for objects that live within one render frame.
	frame_allocator:  runtime.Allocator,
	frame_arena:      runtime.Arena,
}

window := Window {
	ready            = false,
	handle           = nil,
	width            = 100,
	height           = 100,
	//
	mouse            = {0, 0},
	wheel            = {0, 0},
	//
	delta            = 0,
	_start_time      = time.Time{0},
	//
	text_trunc_width = 0,
	text_trunc_x     = 0,
	//
	frame_arena      = runtime.Arena{},
	frame_allocator  = runtime.Allocator{},
}

@(private)
_size_callback :: proc "c" (_: glfw.WindowHandle, w: i32, h: i32) {
	window.width = f32(w)
	window.height = f32(h)
}

@(private)
_cursor_pos_callback :: proc "c" (_: glfw.WindowHandle, x: f64, y: f64) {
	window.mouse.x = math.floor(f32(x))
	window.mouse.y = math.floor(f32(y))
}

@(private)
_scroll_callback :: proc "c" (_: glfw.WindowHandle, x: f64, y: f64) {
	window.wheel.x = f32(x)
	window.wheel.y = f32(y)
}

window_init :: proc(title: cstring, app_id: cstring, width, height: f32) {
	ok := glfw.Init()
	if !ok {
		// TODO: log failure message
		os.exit(1)
	}

	log.info("GLFW initialized")

	// Init window state
	window.width = width
	window.height = height
	window.frame_allocator = runtime.arena_allocator(&window.frame_arena)

	glfw.DefaultWindowHints()

	// Window attributes
	glfw.WindowHint(glfw_.AUTO_ICONIFY, false)
	glfw.WindowHint(glfw_.FLOATING, true)
	glfw.WindowHint(glfw_.RESIZABLE, false)
	glfw.WindowHintString(glfw_.WAYLAND_APP_ID, app_id)

	// OpenGL version.
	// Using 3.3 because i feel like it is the latest and most supported version.
	glfw.WindowHint(glfw_.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw_.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw_.OPENGL_PROFILE, glfw_.OPENGL_CORE_PROFILE)

	handle := glfw.CreateWindow(i32(window.width), i32(window.height), title, nil, nil)
	window.handle = handle
	if handle == nil {
		// TODO: log failure message
		os.exit(1)
	}

	glfw.MakeContextCurrent(handle)
	glfw.SwapInterval(1) // enable v-sync

	rlgl.LoadExtensions(glfw.GetProcAddress)

	// Check window size because it may differ on window creation
	w, h: i32
	glfw.GetWindowSize(handle, &w, &h)
	window.width = f32(w)
	window.height = f32(h)
	rlgl.Init(w, h)

	glfw.SetWindowSizeCallback(handle, _size_callback)
	glfw.SetCursorPosCallback(handle, _cursor_pos_callback)
	glfw.SetScrollCallback(handle, _scroll_callback)

	window.ready = true

	log.info("Window successfully opened")
}

window_should_close :: proc() -> bool {
	return bool(glfw.WindowShouldClose(window.handle))
}

begin_frame :: proc(color: Color) {
	window._start_time = time.now()

	rlgl.Viewport(0, 0, i32(window.width), i32(window.height))
	rlgl.ClearColor(color.r, color.g, color.b, color.a)
	rlgl.ClearScreenBuffers()
}

end_frame :: proc() {
	window.wheel = {0, 0}

	rlgl.DrawRenderBatchActive()
	glfw.SwapBuffers(window.handle)
	time.sleep(1000 / TARGET_FPS * time.Millisecond)
	glfw.PollEvents()

	window.delta = u32(time.duration_milliseconds(time.since(window._start_time)))
}

window_close :: proc() {
	rlgl.Close()
	glfw.DestroyWindow(window.handle)
	glfw.Terminate()
	log.info("Window successfully closed")
}

window_rect :: proc() -> Rect {
	return Rect{0, 0, window.width, window.height}
}
