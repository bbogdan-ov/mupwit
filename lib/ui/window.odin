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

Mouse_Button :: enum {
	Left,
	Middle,
	Right,
}

Cursor :: enum {
	Default       = 0,
	Arrow         = 1,
	Ibeam         = 2,
	Crosshair     = 3,
	Pointing_Hand = 4,
	Resize_Ew     = 5,
	Resize_Ns     = 6,
	Resize_Nwse   = 7,
	Resize_Nesw   = 8,
	Resize_All    = 9,
	Not_Allowed   = 10,
}

Window :: struct #all_or_none {
	ready:             bool,
	handle:            glfw.WindowHandle,
	width:             f32,
	height:            f32,

	// Mouse position
	mouse:             Point,
	mouse_button:      Mouse_Button,
	is_mouse_down:     bool,
	is_mouse_pressed:  bool,
	is_mouse_released: bool,
	cursor:            Cursor,
	// Mouse wheel movement
	wheel:             Point,

	// Time elapsed since the last frame in milliseconds.
	delta:             u32,
	_start_time:       time.Time,

	// Text truncation
	text_trunc_width:  f32,
	text_trunc_x:      f32,

	// Arena allocator for objects that live within one render frame.
	frame_allocator:   runtime.Allocator,
	frame_arena:       runtime.Arena,
}

window := Window {
	ready             = false,
	handle            = nil,
	width             = 100,
	height            = 100,
	//
	mouse             = {0, 0},
	mouse_button      = .Left,
	is_mouse_down     = false,
	is_mouse_pressed  = false,
	is_mouse_released = false,
	cursor            = .Default,
	wheel             = {0, 0},
	//
	delta             = 0,
	_start_time       = time.Time{0},
	//
	text_trunc_width  = 0,
	text_trunc_x      = 0,
	//
	frame_arena       = runtime.Arena{},
	frame_allocator   = runtime.Allocator{},
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
_scroll_callback :: proc "c" (_: glfw.WindowHandle, x, y: f64) {
	window.wheel.x = f32(x)
	window.wheel.y = f32(y)
}

@(private)
_mouse_button_callback :: proc "c" (_: glfw.WindowHandle, button, action, mods: i32) {
	if action == glfw_.RELEASE {
		window.is_mouse_down = false
		window.is_mouse_released = true
	}

	if action != glfw_.PRESS do return

	if button & glfw_.MOUSE_BUTTON_LEFT != 0 {
		window.mouse_button = .Left
	} else if button & glfw_.MOUSE_BUTTON_RIGHT != 0 {
		window.mouse_button = .Right
	} else if button & glfw_.MOUSE_BUTTON_MIDDLE != 0 {
		window.mouse_button = .Middle
	}

	window.is_mouse_down = true
	window.is_mouse_pressed = true
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
	glfw.WindowHint(glfw_.AUTO_ICONIFY, 0)
	glfw.WindowHint(glfw_.FLOATING, 1)
	glfw.WindowHint(glfw_.RESIZABLE, 0)
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
	glfw.SetMouseButtonCallback(handle, _mouse_button_callback)

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
	rlgl.DrawRenderBatchActive()
	glfw.SwapBuffers(window.handle)

	if window.cursor == .Default {
		glfw.SetCursor(window.handle, nil)
	} else {
		MAGICK :: 0x00036000 // this magicky number was taken from RAYLIB source code
		glfw.SetCursor(window.handle, glfw.CreateStandardCursor(MAGICK + i32(window.cursor)))
	}

	window.wheel = {0, 0}
	window.is_mouse_pressed = false
	window.is_mouse_released = false
	window.cursor = .Default

	time.sleep(1000 / TARGET_FPS * time.Millisecond)
	glfw.PollEvents()

	window.delta = u32(time.duration_milliseconds(time.since(window._start_time)))

	free_all(window.frame_allocator)
}

window_close :: proc() {
	rlgl.Close()
	glfw.DestroyWindow(window.handle)
	glfw.Terminate()
	log.info("Window successfully closed")
}

window_rect :: #force_inline proc() -> Rect {
	return Rect{0, 0, window.width, window.height}
}

set_cursor :: #force_inline proc(cursor: Cursor) {
	window.cursor = cursor
}

// Whether the left mouse button was pressed once.
is_clicked :: #force_inline proc() -> bool {
	return is_button_pressed(.Left)
}
// Is mouse button being held down.
is_button_down :: #force_inline proc(button: Mouse_Button) -> bool {
	return window.is_mouse_down && window.mouse_button == button
}
// Is mouse button was pressed once.
is_button_pressed :: #force_inline proc(button: Mouse_Button) -> bool {
	return window.is_mouse_pressed && window.mouse_button == button
}
// Is mouse button was released.
is_button_released :: #force_inline proc(button: Mouse_Button) -> bool {
	return window.is_mouse_released && window.mouse_button == button
}
