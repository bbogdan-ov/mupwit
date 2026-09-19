#include <stdlib.h>
#include <string.h>

#include <freetype2/ft2build.h>
#include FT_FREETYPE_H

#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>
#include <cairo/cairo.h>
#include <cairo/cairo-ft.h>

#include <wayclient.h>

static_assert(sizeof(bool) == 1);

typedef struct My_Window My_Window;

typedef enum {
	MY_BUTTON_UNKNOWN = 0,
	MY_BUTTON_LEFT,
	MY_BUTTON_MIDDLE,
	MY_BUTTON_RIGHT,
	MY_BUTTON_FORWARD,
	MY_BUTTON_BACK,
} My_Button;

typedef enum {
	MY_BUTTON_RELEASED = 0,
	MY_BUTTON_PRESSED,
} My_Button_State;

// Simply renamed `enum wp_cursor_shape_device_v1_shape - 1`.
typedef enum {
	MY_CURSOR_DEFAULT = 0,
	MY_CURSOR_CONTEXT_MENU,
	MY_CURSOR_HELP,
	MY_CURSOR_POINTER,
	MY_CURSOR_PROGRESS,
	MY_CURSOR_WAIT,
	MY_CURSOR_CELL,
	MY_CURSOR_CROSSHAIR,
	MY_CURSOR_TEXT,
	MY_CURSOR_VERTICAL_TEXT,
	MY_CURSOR_ALIAS,
	MY_CURSOR_COPY,
	MY_CURSOR_MOVE,
	MY_CURSOR_NO_DROP,
	MY_CURSOR_NOT_ALLOWED,
	MY_CURSOR_GRAB,
	MY_CURSOR_GRABBING,
	MY_CURSOR_E_RESIZE,
	MY_CURSOR_N_RESIZE,
	MY_CURSOR_NE_RESIZE,
	MY_CURSOR_NW_RESIZE,
	MY_CURSOR_S_RESIZE,
	MY_CURSOR_SE_RESIZE,
	MY_CURSOR_SW_RESIZE,
	MY_CURSOR_W_RESIZE,
	MY_CURSOR_EW_RESIZE,
	MY_CURSOR_NS_RESIZE,
	MY_CURSOR_NESW_RESIZE,
	MY_CURSOR_NWSE_RESIZE,
	MY_CURSOR_COL_RESIZE,
	MY_CURSOR_ROW_RESIZE,
	MY_CURSOR_ALL_SCROLL,
	MY_CURSOR_ZOOM_IN,
	MY_CURSOR_ZOOM_OUT,
	MY_CURSOR_DND_ASK,
	MY_CURSOR_ALL_RESIZE,
} My_Cursor;

typedef void (*My_Frame_Callback)(My_Window *window);
typedef void (*My_Draw_Callback)(My_Window *window, cairo_t *cr, cairo_surface_t *surface);
typedef void (*My_Pointer_Button_Callback)(My_Window *window, My_Button button, My_Button_State state);
typedef void (*My_Pointer_Motion_Callback)(My_Window *window, double x, double y);
typedef void (*My_Pointer_Scroll_Callback)(My_Window *window, double x, double y, bool touchpad);
typedef void (*My_Pointer_Enter_Callback)(My_Window *window, bool leave);

struct My_Window {
	Wayclient_State state;

	void *userdata;
	My_Frame_Callback on_frame;
	My_Draw_Callback draw;
	My_Pointer_Button_Callback on_pointer_button;
	My_Pointer_Motion_Callback on_pointer_motion;
	My_Pointer_Scroll_Callback on_pointer_scroll;
	My_Pointer_Enter_Callback on_pointer_enter;
};

void my__on_frame(Wayclient_State *state) {
	My_Window *window = state->userdata;
	if (window->on_frame != NULL)
		window->on_frame(window);
}

void my__draw(Wayclient_State *state, uint8_t *pixel_data, size_t pixel_data_size) {
	My_Window *window = state->userdata;
	if (window->draw == NULL) return;

	cairo_surface_t *surface = cairo_image_surface_create_for_data(
		pixel_data,
		CAIRO_FORMAT_ARGB32,
		state->width,
		state->height,
		state->width * 4
	);
	cairo_t *cr = cairo_create(surface);

	window->draw(window, cr, surface);

	cairo_destroy(cr);
	cairo_surface_destroy(surface);
}

void my__on_pointer_button(Wayclient_State *state, uint32_t wl_button, enum wl_pointer_button_state wl_state) {
	My_Window *window = state->userdata;
	if (window->on_pointer_button == NULL) return;

	My_Button button = MY_BUTTON_UNKNOWN;
	My_Button_State button_state = MY_BUTTON_PRESSED;

	switch (wl_button) {
	case BTN_LEFT:   button = MY_BUTTON_LEFT; break;
	case BTN_RIGHT:  button = MY_BUTTON_RIGHT; break;
	case BTN_MIDDLE: button = MY_BUTTON_MIDDLE; break;

	case BTN_FORWARD:
	case BTN_EXTRA: button = MY_BUTTON_FORWARD; break;

	case BTN_BACK:
	case BTN_SIDE: button = MY_BUTTON_BACK; break;

	case BTN_TASK: break;
	}

	switch (wl_state) {
	case WL_POINTER_BUTTON_STATE_RELEASED: button_state = MY_BUTTON_RELEASED; break;
	case WL_POINTER_BUTTON_STATE_PRESSED:  button_state = MY_BUTTON_PRESSED; break;
	}

	window->on_pointer_button(window, button, button_state);
}

void my__on_pointer_motion(Wayclient_State *state, double x, double y) {
	My_Window *window = state->userdata;

	if (window->on_pointer_motion != NULL)
		window->on_pointer_motion(window, x, y);
}

void my__on_pointer_scroll(Wayclient_State *state, double x, double y, enum wl_pointer_axis_source source) {
	My_Window *window = state->userdata;

	if (window->on_pointer_scroll != NULL) {
		bool touchpad = source == WL_POINTER_AXIS_SOURCE_FINGER;
		window->on_pointer_scroll(window, x, y, touchpad);
	}
}

void my__on_pointer_enter(Wayclient_State *state) {
	My_Window *window = state->userdata;
	if (window->on_pointer_enter != NULL)
		window->on_pointer_enter(window, false);
}
void my__on_pointer_leave(Wayclient_State *state) {
	My_Window *window = state->userdata;
	if (window->on_pointer_enter != NULL)
		window->on_pointer_enter(window, true);
}

My_Window *
my_new(uint32_t width, uint32_t height) {
	My_Window *window = calloc(1, sizeof(My_Window));
	if (window == NULL)
		return NULL;

	wayclient_init(&window->state, width, height);

	window->state.userdata = window;
	window->state.on_frame = my__on_frame;
	window->state.draw = my__draw;
	window->state.on_pointer_button = my__on_pointer_button;
	window->state.on_pointer_motion = my__on_pointer_motion;
	window->state.on_pointer_scroll = my__on_pointer_scroll;
	window->state.on_pointer_enter = my__on_pointer_enter;
	window->state.on_pointer_leave = my__on_pointer_leave;

	Wayclient_Error err = wayclient_run(&window->state);
	if (err != WAYCLIENT_OK)
		return NULL;

	return window;
}

void
my_destroy(My_Window *window) {
	wayclient_destroy(&window->state);
	free(window);
}

bool
my_should_run(My_Window *window) {
	return wl_display_dispatch(window->state.wl_display) != -1 && !window->state.should_close;
}

void
my_set_userdata(My_Window *window, void *userdata) {
	window->userdata = userdata;
}
void
my_set_resizable(My_Window *window, bool resizable) {
	window->state.resizable = resizable;
}

void
my_set_cursor(My_Window *window, My_Cursor cursor) {
	wayclient_set_cursor(&window->state, (enum wp_cursor_shape_device_v1_shape)(cursor + 1));
}

void my_set_frame_callback(My_Window *w, My_Frame_Callback cb)                   { w->on_frame = cb; }
void my_set_draw_callback(My_Window *w, My_Draw_Callback cb)                     { w->draw = cb; }
void my_set_pointer_button_callback(My_Window *w, My_Pointer_Button_Callback cb) { w->on_pointer_button = cb; }
void my_set_pointer_motion_callback(My_Window *w, My_Pointer_Motion_Callback cb) { w->on_pointer_motion = cb; }
void my_set_pointer_scroll_callback(My_Window *w, My_Pointer_Scroll_Callback cb) { w->on_pointer_scroll = cb; }
void my_set_pointer_enter_callback(My_Window *w, My_Pointer_Enter_Callback cb)   { w->on_pointer_enter = cb; }

void *
my_userdata(My_Window *window) {
	return window->userdata;
}

// ------------------------------
// Fonts.
// ------------------------------

bool
my_font_library_init(FT_Library *library) {
	return FT_Init_FreeType(library) == 0;
}

bool
my_font_face_load(FT_Library library, FT_Face *face, const uint8_t *data, uint32_t size, uint32_t face_index) {
	return FT_New_Memory_Face(library,data, (FT_Long)size, (FT_Long)face_index, face) == 0;
}

void
my_font_face_destroy(FT_Face face) {
	FT_Done_Face(face);
}

void
my_font_library_destroy(FT_Library library) {
	FT_Done_FreeType(library);
}
