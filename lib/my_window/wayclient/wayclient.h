#ifndef WAYCLIENT_H
#define WAYCLIENT_H

#include <stdint.h>

#include <wayland-client.h>
#include "xdg_shell.h"
#include "cursor_shape_v1.h"
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
} Wayclient_Error;

typedef struct {
	struct wl_buffer *wl_buffer;
	uint8_t          *data; // Pixel data of the wl_buffer.
	bool             attached; // Whether the buffer is being used.
} Wayclient_Buffer;

typedef struct Wayclient_State Wayclient_State;

struct Wayclient_State {
	struct wl_display    *wl_display;
	struct wl_registry   *wl_registry;
	struct wl_compositor *wl_compositor;
	struct wl_surface    *wl_surface;
	struct wl_shm        *wl_shm;
	uint8_t              *pool_data;
	Wayclient_Buffer     buffers[WAYCLIENT_BUFFER_COUNT];

	struct wl_seat       *wl_seat;
	struct wl_pointer    *wl_pointer;
	struct wl_keyboard   *wl_keyboard;
	struct xkb_context   *xkb_context;
	struct xkb_state     *xkb_state;
	xkb_mod_mask_t       shift_mask;
	xkb_mod_mask_t       ctrl_mask;
	xkb_mod_mask_t       alt_mask;
	// Use this field to determine what modifiers were pressed.
	// For example:
	// ```c
	// if ((state.pressed_mods_mask & state.shift_mask) != 0) {
	//     // Shift is pressed!
	// }
	// ```
	xkb_mod_mask_t       pressed_mods_mask;
	uint32_t             repeat_rate_ms;
	uint32_t             repeat_delay_ms;
	uint32_t             repeat_timer_ms;
	uint32_t             last_pressed_key;
	bool                 is_repeating;

	struct wp_cursor_shape_manager_v1 *wp_cursor_manager;
	struct wp_cursor_shape_device_v1  *wp_cursor_device;
	enum wp_cursor_shape_device_v1_shape cursor;
	uint32_t pointer_enter_serial;

	struct wl_callback   *wl_frame_callback;

	struct xdg_wm_base   *xdg_wm_base;
	struct xdg_surface   *xdg_surface;
	struct xdg_toplevel  *xdg_toplevel;

	enum wl_pointer_axis_source scroll_source;

	uint32_t             width, height;
	uint32_t             prev_width, prev_height;
	bool                 should_close;
	bool                 resizable;
	bool                 draw_each_frame;

	// Callbacks.
	void *userdata;
	// Called N times per second (usually 60) by the compositor when the window is displayed.
	// May be called much less frequently if compositor decides so (for example when window is not visible).
	void (*on_frame)(Wayclient_State *state);
	// Called everytime `wayclient_draw_and_commit` being called, usually 60
	// times per second after `on_frame` callback. (see `on_frame`)
	// You can set `Wayclient_State.draw_each_frame` to false and call
	// `wayclient_draw_and_commit` whenever you want.
	void (*draw)(Wayclient_State *state, uint8_t *pixel_data, size_t pixel_data_size);
	void (*on_resize)(Wayclient_State *state);

	void (*on_pointer_enter)(Wayclient_State *state);
	void (*on_pointer_leave)(Wayclient_State *state);
	void (*on_pointer_motion)(Wayclient_State *state, double x, double y);
	// `button` is a button code defined in the "linux/input-event-codes.h" header. (e.g. `BTN_LEFT`)
	void (*on_pointer_button)(Wayclient_State *state, uint32_t button, enum wl_pointer_button_state button_state);
	void (*on_pointer_scroll)(Wayclient_State *state, double x, double y, enum wl_pointer_axis_source source);

	// Keyboard focuses the window.
	// I think it is similar to when user focuses the window?
	void (*on_keyboard_enter)(Wayclient_State *state);
	// Keyboard unfocuses the window.
	// I think it is similar to when user unfocuses the window?
	void (*on_keyboard_leave)(Wayclient_State *state);
	// `keycode` is a keycode defined in the "linux/input-event-codes.h" header. (e.g. `KEY_Q`)
	void (*on_keyboard_key)(
		Wayclient_State *state,
		uint32_t keycode,
		xkb_keysym_t keysym,
		enum wl_keyboard_key_state key_state
	);
};

// ------------------------------
// Public functions.
// ------------------------------

void
wayclient_init(Wayclient_State *state, uint32_t width, uint32_t height);

Wayclient_Error
wayclient_run(Wayclient_State *state);

// Clean up the memory and disconnect from the Wayland display.
void
wayclient_destroy(Wayclient_State *state);

// Call user draw callback, damage and commit the surface to the compositor.
// Returns whether the draw call was successfull or cancelled due to all
// buffers are being used by the compositor.
bool
wayclient_draw_and_commit(Wayclient_State *state);

bool
wayclient_set_cursor(Wayclient_State *state, enum wp_cursor_shape_device_v1_shape cursor);

// FIXME!!: using `on_frame` to update timers will cap repetition rate to the
// rate this callback is being called at. (usually 60 times per second)
// So if `on_frame` is being called 60 times per seconds, the max repetition
// rate your app can handle will be 60.
// This is not a problem for most people i think, so it'll work for now. But it
// looks like some apps handle this properly. (Alacritty for example can handle
// almost any repeatition rate)

// Updates timers needed to implement key repetition event, due to some
// compositors don't fire this event themselves.
// Call this in the `on_frame` callback of your app.
// `elapsed_ms` is time in milliseconds passed since previous frame.
void
wayclient_update_key_repetition(Wayclient_State *state, uint32_t elapsed_ms);

// ------------------------------
// Internal functions.
// ------------------------------

void
wayclient__invoke_keyboard_key_event(Wayclient_State *state, uint32_t key, uint32_t key_state);

// Update buffers and SHM pool accordingly to the current window size.
void
wayclient__update_buffers_size(Wayclient_State *state);

// Returns the index of the first buffer that is not used by the compositor.
// Returns -1 if all buffers are being used.
uint32_t
wayclient__first_released_buffer_index(Wayclient_State *state);

void
wayclient__destroy_and_unmap_buffers(Wayclient_State *state);

void
wayclient__randname(char *buf, int n);

int
wayclient__create_shm_file(size_t size);

#endif
