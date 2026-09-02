#ifndef WAYCLIENT_H
#define WAYCLIENT_H

#include <stdint.h>

#include <wayland-client.h>
#include "xdg_shell.h"
#include <xkbcommon/xkbcommon.h>
#include <linux/input-event-codes.h>

#define wayclient_log(msg)       fprintf(stderr, "WAYCLIENT: "msg"\n")
#define wayclient_logf(fmt, ...) fprintf(stderr, "WAYCLIENT: "fmt"\n", __VA_ARGS__)

// Format of a pixel.
#define WAYCLIENT_PIXEL_FORMAT WL_SHM_FORMAT_ARGB8888
// Number of components in a pixel. (ARGB)
#define WAYCLIENT_PIXEL_SIZE 4

// Double-buffered by default.
#define WAYCLIENT_BUFFER_COUNT 2

// ------------------------------
// Types.
// ------------------------------

typedef enum {
	WAYCLIENT_OK = 0,
	WAYCLIENT_ERR_CONNECT,
	WAYCLIENT_ERR_GET_OBJECTS,
	WAYCLIENT_ERR_CREATE_SURFACE,
	WAYCLIENT_ERR_CREATE_TOPLEVEL,
} wayclient_error;

typedef struct {
	struct wl_buffer *wl_buffer;
	uint8_t          *data; // Pixel data of the wl_buffer.
	bool             attached; // Whether the buffer is being used.
} wayclient_buffer;

typedef struct wayclient_state wayclient_state;

struct wayclient_state {
	struct wl_display    *wl_display;
	struct wl_registry   *wl_registry;
	struct wl_compositor *wl_compositor;
	struct wl_surface    *wl_surface;
	struct wl_shm        *wl_shm;
	uint8_t              *pool_data;
	wayclient_buffer     buffers[WAYCLIENT_BUFFER_COUNT];

	struct wl_seat       *wl_seat;
	struct wl_pointer    *wl_pointer;
	struct wl_keyboard   *wl_keyboard;
	struct xkb_context   *xkb_context;
	struct xkb_state     *xkb_state;

	struct wl_callback   *wl_frame_callback;

	struct xdg_wm_base   *xdg_wm_base;
	struct xdg_surface   *xdg_surface;
	struct xdg_toplevel  *xdg_toplevel;

	uint32_t             width, height;
	uint32_t             prev_width, prev_height;
	bool                 should_close;
	bool                 resizable;
	bool                 draw_each_frame;

	// Callbacks.
	void *userdata;
	// Called N times per second (usually 60) by the compositor when the window is displayed.
	// May be called much less frequently if compositor decides so (for example when window is not visible).
	void (*on_frame)(wayclient_state *state);
	// Called everytime `wayclient_draw_and_commit` being called, usually 60
	// times per second after `on_frame` callback. (see `on_frame`)
	// You can set `wayclient_state.draw_each_frame` to false and call
	// `wayclient_draw_and_commit` whenever you want.
	void (*draw)(wayclient_state *state, uint8_t *pixel_data, size_t pixel_data_size);
	void (*on_resize)(wayclient_state *state);

	void (*on_pointer_enter)(wayclient_state *state);
	void (*on_pointer_leave)(wayclient_state *state);
	void (*on_pointer_motion)(wayclient_state *state, double x, double y);
	// `button` is a button code defined in the "linux/input-event-codes.h" header. (e.g. `BTN_LEFT`)
	void (*on_pointer_button)(wayclient_state *state, uint32_t button, enum wl_pointer_button_state button_state);
	void (*on_pointer_scroll)(wayclient_state *state, double x, double y);

	// Keyboard focuses the window.
	// I think it is similar to when user focuses the window?
	void (*on_keyboard_enter)(wayclient_state *state);
	// Keyboard unfocuses the window.
	// I think it is similar to when user unfocuses the window?
	void (*on_keyboard_leave)(wayclient_state *state);
	// `keycode` is a keycode defined in the "linux/input-event-codes.h" header. (e.g. `KEY_Q`)
	void (*on_keyboard_key)(
		wayclient_state *state,
		uint32_t keycode,
		xkb_keysym_t keysym,
		enum wl_keyboard_key_state key_state
	);
};

// ------------------------------
// Public functions.
// ------------------------------

void
wayclient_init(wayclient_state *state, uint32_t width, uint32_t height);

wayclient_error
wayclient_run(wayclient_state *state);

// Clean up the memory and disconnect from the Wayland display.
void
wayclient_destroy(wayclient_state *state);

// Call user draw callback, damage and commit the surface to the compositor.
// Returns whether the draw call was successfull or cancelled due to all
// buffers are being used by the compositor.
bool
wayclient_draw_and_commit(wayclient_state *state);

// ------------------------------
// Internal functions.
// ------------------------------

// Update buffers and SHM pool accordingly to the current window size.
void
wayclient__update_buffers_size(wayclient_state *state);

// Returns the index of the first buffer that is not used by the compositor.
// Returns -1 if all buffers are being used.
uint32_t
wayclient__first_released_buffer_index(wayclient_state *state);

void
wayclient__destroy_and_unmap_buffers(wayclient_state *state);

void
wayclient__randname(char *buf, int n);

int
wayclient__create_shm_file(size_t size);

#endif
