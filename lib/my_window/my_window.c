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

typedef void (*Draw_Callback)(My_Window *window, cairo_t *cr, cairo_surface_t *surface);
typedef void (*Pointer_Motion_Callback)(My_Window *window, double x, double y);

struct My_Window {
	wayclient_state state;

	void *userdata;
	Draw_Callback draw;
	Pointer_Motion_Callback on_pointer_motion;
};

void draw(wayclient_state *state, uint8_t *pixel_data, size_t pixel_data_size) {
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

void on_pointer_motion(wayclient_state *state, double x, double y) {
	My_Window *window = state->userdata;

	if (window->on_pointer_motion != NULL)
		window->on_pointer_motion(window, x, y);
}

My_Window *
my_window_new(uint32_t width, uint32_t height) {
	My_Window *window = calloc(1, sizeof(My_Window));
	if (window == NULL)
		return NULL;

	wayclient_init(&window->state, width, height);

	window->state.userdata = window;
	window->state.draw = draw;
	window->state.on_pointer_motion = on_pointer_motion;

	wayclient_error err = wayclient_run(&window->state);
	if (err != WAYCLIENT_OK)
		return NULL;

	return window;
}

void
my_window_destroy(My_Window *window) {
	wayclient_destroy(&window->state);
	free(window);
}

bool
my_window_should_run(My_Window *window) {
	return wl_display_dispatch(window->state.wl_display) != -1 && !window->state.should_close;
}

void
my_window_set_userdata(My_Window *window, void *userdata) {
	window->userdata = userdata;
}
void
my_window_set_resizable(My_Window *window, bool resizable) {
	window->state.resizable = resizable;
}

void my_window_set_draw_callback(My_Window *window, Draw_Callback callback) { window->draw = callback; }
void my_window_set_pointer_motion_callback(My_Window *window, Pointer_Motion_Callback callback) { window->on_pointer_motion = callback; }

void *
my_window_userdata(My_Window *window) {
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
