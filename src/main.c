#include <stdio.h>
#include <raylib.h>
#include <assert.h>
#include <unistd.h>

#include "./assets.h"
#include "./state.h"
#include "./client.h"
#include "./macros.h"
#include "./theme.h"
#include "./restore.h"
#include "./pages/player_page.h"
#include "./pages/queue_page.h"
#include "./ui/draw.h"
#include "./ui/currently_playing.h"

// TODO: add ability to undo actions like queue reordering or song selection
// TODO: add log file in release file

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
	Assets assets = assets_new();

	QueuePage queue_page = queue_page_new();

	while (true) {
		if (should_close()) {
			client_push_action_kind(&client, ACTION_CLOSE);
			break;
		}

		client_clear_events(&client);

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

			state_update(&state, &client);
			queue_page_update(&queue_page, &client);
		}

		BeginDrawing();

		if (should_skip_drawing()) {
			// It will update every second instead of 60 times per second so we
			// don't waste CPU resources
			sleep(1);

			// NOTE: we are still calling BeginDrawing() and EndDrawing() because
			// it is essential to things like GetFrameTime() to work
			EndDrawing();
			continue;
		}

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
				player_page_draw(&client, &state, &assets);

				queue_page_draw(&queue_page, &client, &state, &assets);

				currently_playing_draw(&client, &state, &assets);
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

	// Wait untill the connection is closed
	client_wait_for_thread(&client);

	TraceLog(LOG_INFO, "MUPWIT: Bye");

	return 0;
}
