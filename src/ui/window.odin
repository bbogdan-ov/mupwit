package ui

import "core:math"
import "core:os"
import "core:time"
import rlgl "rlgl"
import glfw_ "vendor:glfw"
import glfw "vendor:glfw/bindings"

Window :: struct #all_or_none {
	ready:  bool,
	handle: glfw.WindowHandle,
	width:  i32,
	height: i32,
	mouse:  Point,
}

window := Window {
	ready  = false,
	handle = nil,
	width  = WINDOW_WIDTH,
	height = WINDOW_HEIGHT,
	mouse  = {},
}

@(private)
_size_callback :: proc "c" (_: glfw.WindowHandle, w: i32, h: i32) {
	window.width = w
	window.height = h
}

@(private)
_cursor_pos_callback :: proc "c" (_: glfw.WindowHandle, x: f64, y: f64) {
	window.mouse.x = math.floor(f32(x))
	window.mouse.y = math.floor(f32(y))
}

window_init :: proc() {
	ok := glfw.Init()
	if !ok {
		// TODO: log failure message
		os.exit(1)
	}

	glfw.DefaultWindowHints()

	// Window attributes
	glfw.WindowHint(glfw_.AUTO_ICONIFY, false)
	glfw.WindowHint(glfw_.FLOATING, true)
	glfw.WindowHint(glfw_.RESIZABLE, false)
	glfw.WindowHintString(glfw_.WAYLAND_APP_ID, WINDOW_TITLE)

	// OpenGL version.
	// Using 3.3 because i feel like it is the latest and most supported version.
	glfw.WindowHint(glfw_.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw_.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw_.OPENGL_PROFILE, glfw_.OPENGL_CORE_PROFILE)

	handle := glfw.CreateWindow(window.width, window.height, WINDOW_TITLE, nil, nil)
	window.handle = handle
	if handle == nil {
		// TODO: log failure message
		os.exit(1)
	}

	glfw.MakeContextCurrent(handle)
	glfw.SwapInterval(1) // enable v-sync

	rlgl.LoadExtensions(glfw.GetProcAddress)

	// Check window size because it may differ on window creation
	glfw.GetWindowSize(handle, &window.width, &window.height)
	rlgl.Init(window.width, window.height)

	glfw.SetWindowSizeCallback(handle, _size_callback)
	glfw.SetCursorPosCallback(handle, _cursor_pos_callback)

	window.ready = true
}

window_should_close :: proc() -> bool {
	return bool(glfw.WindowShouldClose(window.handle))
}

begin_frame :: proc(color: Color) {
	rlgl.Viewport(0, 0, window.width, window.height)
	rlgl.ClearColor(color.r, color.g, color.b, color.a)
	rlgl.ClearScreenBuffers()
}

end_frame :: proc() {
	rlgl.DrawRenderBatchActive()
	glfw.SwapBuffers(window.handle)
	time.sleep(1000 / TARGET_FPS * time.Millisecond)
	glfw.PollEvents()
}

window_close :: proc() {
	rlgl.Close()
	glfw.DestroyWindow(window.handle)
	glfw.Terminate()
}
