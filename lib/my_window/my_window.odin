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

Button :: enum i32 {
	Unknown = 0,
	Left,
	Middle,
	Right,
	Forward,
	Back,
}

Button_State :: enum i32 {
	Released = 0,
	Pressed,
}

Cursor :: enum i32 {
	Default = 0,
	Context_Menu,
	Help,
	Pointer,
	Progress,
	Wait,
	Cell,
	Crosshair,
	Text,
	Vertical_Text,
	Alias,
	Copy,
	Move,
	No_Drop,
	Not_Allowed,
	Grab,
	Grabbing,
	E_Resize,
	N_Resize,
	NE_Resize,
	NW_Resize,
	S_Resize,
	SE_Resize,
	SW_Resize,
	W_Resize,
	EW_Resize,
	NS_Resize,
	NESW_Resize,
	NWSE_Resize,
	Col_Resize,
	Row_Resize,
	All_Scroll,
	Zoom_In,
	Zoom_Out,
	Dnd_Ask,
	All_Resize,
}

Callback :: #type proc "c" (win: ^Window)
Draw_Callback :: #type proc "c" (win: ^Window, cr: ^cairo.cairo_t, surface: ^cairo.surface_t)
Pointer_Button_Callback :: #type proc "c" (win: ^Window, button: Button, state: Button_State)
Pointer_Motion_Callback :: #type proc "c" (win: ^Window, x, y: f64)
Pointer_Scroll_Callback :: #type proc "c" (win: ^Window, x, y: f64, touchpad: bool)
Pointer_Enter_Callback :: #type proc "c" (win: ^Window, leave: bool)

@(default_calling_convention = "c", link_prefix = "my_")
foreign lib {
	@(require_results)
	new :: proc(width, height: u32) -> ^Window ---
	destroy :: proc(win: ^Window) ---

	should_run :: proc(win: ^Window) -> bool ---

	set_userdata :: proc(win: ^Window, userdata: rawptr) ---
	set_resizable :: proc(win: ^Window, resizable: bool) ---
	set_cursor :: proc(win: ^Window, cursor: Cursor) ---
	set_frame_callback :: proc(win: ^Window, callback: Callback) ---
	set_draw_callback :: proc(win: ^Window, callback: Draw_Callback) ---
	set_pointer_button_callback :: proc(win: ^Window, callback: Pointer_Button_Callback) ---
	set_pointer_motion_callback :: proc(win: ^Window, callback: Pointer_Motion_Callback) ---
	set_pointer_scroll_callback :: proc(win: ^Window, callback: Pointer_Scroll_Callback) ---
	set_pointer_enter_callback :: proc(win: ^Window, callback: Pointer_Enter_Callback) ---

	userdata :: proc(win: ^Window) -> rawptr ---

	@(require_results)
	font_library_init :: proc(library: ^Font_Library) -> (ok: bool) ---
	@(require_results)
	font_face_load :: proc(library: Font_Library, face: ^Font_Face, data: [^]u8, size, face_index: u32) -> (ok: bool) ---
	font_face_destroy :: proc(face: Font_Face) ---
	font_library_destroy :: proc(library: Font_Library) ---
}
