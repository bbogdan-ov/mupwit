package my_window

@(require) foreign import _wl "system:wayland-client"
@(require) foreign import _xkb "system:xkbcommon"
@(require) foreign import _ft "system:freetype"
_ :: _wl
_ :: _xkb
_ :: _ft

@(require) foreign import lib "./lib/libmywindow.a"

import "lib:cairo"

Font_Library :: cairo.Font_Library
Font_Face :: cairo.Font_Face

Window :: struct {}

Button :: enum {
	Unknown = 0,
	Left,
	Middle,
	Right,
	Forward,
	Back,
}

Button_State :: enum {
	Released = 0,
	Pressed,
}

Callback :: #type proc "c" (win: ^Window)
Draw_Callback :: #type proc "c" (win: ^Window, cr: ^cairo.cairo_t, surface: ^cairo.surface_t)
Pointer_Button_Callback :: #type proc "c" (win: ^Window, button: Button, state: Button_State)
Pointer_Motion_Callback :: #type proc "c" (win: ^Window, x, y: f64)
Pointer_Scroll_Callback :: #type proc "c" (win: ^Window, x, y: f64, touchpad: bool)

@(default_calling_convention = "c", link_prefix = "my_")
foreign lib {
	@(require_results)
	window_new :: proc(width, height: u32) -> ^Window ---
	window_destroy :: proc(win: ^Window) ---

	window_should_run :: proc(win: ^Window) -> bool ---

	window_set_userdata :: proc(win: ^Window, userdata: rawptr) ---
	window_set_resizable :: proc(win: ^Window, resizable: bool) ---
	window_set_frame_callback :: proc(win: ^Window, callback: Callback) ---
	window_set_draw_callback :: proc(win: ^Window, callback: Draw_Callback) ---
	window_set_pointer_button_callback :: proc(win: ^Window, callback: Pointer_Button_Callback) ---
	window_set_pointer_motion_callback :: proc(win: ^Window, callback: Pointer_Motion_Callback) ---
	window_set_pointer_scroll_callback :: proc(win: ^Window, callback: Pointer_Scroll_Callback) ---

	window_userdata :: proc(win: ^Window) -> rawptr ---

	@(require_results)
	font_library_init :: proc(library: ^Font_Library) -> (ok: bool) ---
	@(require_results)
	font_face_load :: proc(library: Font_Library, face: ^Font_Face, data: [^]u8, size, face_index: u32) -> (ok: bool) ---
	font_face_destroy :: proc(face: Font_Face) ---
	font_library_destroy :: proc(library: Font_Library) ---
}
