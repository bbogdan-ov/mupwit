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
#include "./pages/albums_page.h"
#include "./pages/queue_page.h"
#include "./ui/draw.h"
#include "./ui/currently_playing.h"
#include "./context.h"

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

	Context ctx = (Context){
		.state = &state,
		.client = &client,
		.assets = &assets,
	};

	QueuePage queue_page = queue_page_new();
	AlbumsPage albums_page = albums_page_new();

	while (true) {
		if (should_close()) {
			client_push_action_kind(&client, ACTION_CLOSE);
			break;
		}

		if (should_skip_drawing()) {
			// Sleep so we don't waste CPU time.
			// This sleep will be interrupted when window gets restored.
			// I think it happens because program receives SIGUSR1 signal.
			// (Probably?... It seems to do so on my machine)
			sleep(10 * 1000);
			continue;
		}

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

			Event event = {0};
			while (true) {
				event = client_pop_event(&client);
				if (event.kind == EVENT_NONE) break;

				state_on_event(&state, event);
				queue_page_on_event(&queue_page, event);
				albums_page_on_event(ctx, event);
			};

			state_update(&state, &client);
		}

		BeginDrawing();
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
				albums_page_draw(&albums_page, ctx);
				player_page_draw(ctx);

				queue_page_draw(&queue_page, ctx);

				currently_playing_draw(ctx);
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

	// NOTE: i don't free any GPU stuff (texture, fonts, etc...) myself because i don't care?
	// And should i?

	state_free(&state);

	// Wait untill the connection is closed
	client_wait_for_thread(&client);

	TraceLog(LOG_INFO, "MUPWIT: Bye");

	return 0;
}
