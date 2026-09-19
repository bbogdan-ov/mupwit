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

Key_State :: enum i32 {
	Released = 0,
	Pressed,
}

Mod :: enum i32 {
	Shift = 0,
	Ctrl,
	Alt,
}
Mods :: bit_set[Mod;i32]

// Binding for some keys in <linux/input-event-codes.h>.
Key :: enum u32 {
	Unknown       = 0,
	Esc           = 1,
	One           = 2,
	Two           = 3,
	Three         = 4,
	Four          = 5,
	Five          = 6,
	Six           = 7,
	Seven         = 8,
	Eight         = 9,
	Nine          = 10,
	Ten           = 11,
	Minus         = 12,
	Equal         = 13,
	Backspace     = 14,
	Tab           = 15,
	Q             = 16,
	W             = 17,
	E             = 18,
	R             = 19,
	T             = 20,
	Y             = 21,
	U             = 22,
	I             = 23,
	O             = 24,
	P             = 25,
	Left_Brace    = 26,
	Right_Brace   = 27,
	Enter         = 28,
	Left_Ctrl     = 29,
	A             = 30,
	S             = 31,
	D             = 32,
	F             = 33,
	G             = 34,
	H             = 35,
	J             = 36,
	K             = 37,
	L             = 38,
	Semicolon     = 39,
	Apostrophe    = 40,
	Grave         = 41,
	Left_Shift    = 42,
	Back_Slash    = 43,
	Z             = 44,
	X             = 45,
	C             = 46,
	V             = 47,
	B             = 48,
	N             = 49,
	M             = 50,
	Comma         = 51,
	Dot           = 52,
	Slash         = 53,
	Right_Shift   = 54,
	Kpasterisk    = 55,
	Left_Alt      = 56,
	Space         = 57,
	Caps_Lock     = 58,
	F1            = 59,
	F2            = 60,
	F3            = 61,
	F4            = 62,
	F5            = 63,
	F6            = 64,
	F7            = 65,
	F8            = 66,
	F9            = 67,
	F10           = 68,
	Num_Lock      = 69,
	Scroll_Lock   = 70,
	KP_7          = 71,
	KP_8          = 72,
	KP_9          = 73,
	KP_Minus      = 74,
	KP_4          = 75,
	KP_5          = 76,
	KP_6          = 77,
	KP_Plus       = 78,
	KP_1          = 79,
	KP_2          = 80,
	KP_3          = 81,
	KP_0          = 82,
	KP_Dot        = 83,
	F11           = 87,
	F12           = 88,
	RO            = 89,
	KP_Enter      = 96,
	Right_Ctrl    = 97,
	KP_Slash      = 98,
	Sysrq         = 99,
	Right_Alt     = 100,
	Line_Feed     = 101,
	Home          = 102,
	Up            = 103,
	Page_Up       = 104,
	Left          = 105,
	Right         = 106,
	End           = 107,
	Down          = 108,
	Page_Down     = 109,
	Insert        = 110,
	Delete        = 111,
	Macro         = 112,
	Mute          = 113,
	Volume_Down   = 114,
	Volume_Up     = 115,
	KP_Equal      = 117,
	KP_Plus_Minus = 118,
	Pause         = 119,
	KP_Comma      = 121,
	Left_Meta     = 125,
	Right_Meta    = 126,
	Compose       = 127,
}

Callback :: #type proc "c" (win: ^Window)
Draw_Callback :: #type proc "c" (win: ^Window, cr: ^cairo.cairo_t, surface: ^cairo.surface_t)
Pointer_Button_Callback :: #type proc "c" (win: ^Window, button: Button, state: Button_State)
Pointer_Motion_Callback :: #type proc "c" (win: ^Window, x, y: f64)
Pointer_Scroll_Callback :: #type proc "c" (win: ^Window, x, y: f64, touchpad: bool)
Pointer_Enter_Callback :: #type proc "c" (win: ^Window, leave: bool)
Keyboard_Key_Callback :: #type proc "c" (win: ^Window, key: Key, key_state: Key_State, mods: Mods)

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
	set_keyboard_key_callback :: proc(win: ^Window, callback: Keyboard_Key_Callback) ---

	userdata :: proc(win: ^Window) -> rawptr ---

	@(require_results)
	font_library_init :: proc(library: ^Font_Library) -> (ok: bool) ---
	@(require_results)
	font_face_load :: proc(library: Font_Library, face: ^Font_Face, data: [^]u8, size, face_index: u32) -> (ok: bool) ---
	font_face_destroy :: proc(face: Font_Face) ---
	font_library_destroy :: proc(library: Font_Library) ---
}
