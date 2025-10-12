#include <stdio.h>
#include <raylib.h>
#include <assert.h>

#include "./client.h"
#include "./state.h"
#include "./macros.h"
#include "./theme.h"
#include "./restore.h"
#include "./pages/player_page.h"
#include "./pages/queue_page.h"
#include "./pages/albums_page.h"
#include "./ui/draw.h"
#include "./ui/currently_playing.h"

// TODO: add ability to undo actions like queue reordering or song selection

int main() {
	if (try_restore()) return 0;

#ifdef RELEASE
	SetTraceLogLevel(LOG_WARNING);
#endif

	InitWindow(THEME_WINDOW_WIDTH, THEME_WINDOW_HEIGHT, "MUPWIT");
	SetTargetFPS(60);

	Client client = client_new();
	client_connect(&client);

	State state = state_new();

	QueuePage queue_page = queue_page_new();
	AlbumsPage albums_page = albums_page_new();

	while (!should_close()) {
		ClientState client_state = client_get_state(&client);

		if (client_state == CLIENT_STATE_READY) {
			bool is_shift = is_shift_down();
			if (is_key_pressed(KEY_TAB)) {
				if (is_shift)
					state_prev_page(&state);
				else
					state_next_page(&state);
			}
			if (is_key_pressed(KEY_SPACE)) {
				client_push_action_kind(&client, ACTION_TOGGLE);
			}

			state_update(&state);
			queue_page_update(&queue_page, &client);
			albums_page_update(&albums_page, &client);

			client_update(&client, &state);
		}

		BeginDrawing();
		if (should_skip_drawing()) continue;

		ClearBackground(state.background);

		state.container = screen_rect();
		state.cursor = MOUSE_CURSOR_DEFAULT;

		switch (client_state) {
			case CLIENT_STATE_DEAD:
				// Do nothing
				break;
			case CLIENT_STATE_CONNECTING:
				// TODO: show proper message
				DrawText("connecting...", 0, 0, 30, BLACK);
				break;
			case CLIENT_STATE_ERROR:
				// TODO: show proper message
				DrawText("error", 0, 0, 30, BLACK);
				break;
			case CLIENT_STATE_READY:
				player_page_draw(&client, &state);
				albums_page_draw(&albums_page, &client, &state);

				queue_page_draw(&queue_page, &client, &state);

				currently_playing_draw(&client, &state);
				break;
		}

#ifdef DEBUG
		double time = GetTime() * 10;
		DrawRectangle(cos(time) * 20 + 20, sin(time) * 20 + 20, 20, 20, ColorAlpha(RED, 0.5));
#endif

		SetMouseCursor(state.cursor);

		EndDrawing();
	}

	CloseWindow();

	client_free(&client);
	queue_page_free(&queue_page);

	return 0;
}
