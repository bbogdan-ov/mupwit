#include <stdio.h>
#include <raylib.h>
#include <assert.h>

#include "client.h"
#include "player.h"
#include "state.h"
#include "macros.h"
#include "theme.h"
#include "pages/player_page.h"
#include "pages/queue_page.h"

int main() {
	InitWindow(THEME_WINDOW_WIDTH, THEME_WINDOW_HEIGHT, "MUPWIT");
	SetTargetFPS(60);

	Client client = client_new();
	client_connect(&client);

	Player player = player_new();
	State state = state_new();

	while (!WindowShouldClose()) {
		client_update(&client, &player, &state);
		state_update(&state);

		if (TRYLOCK(&client.conn_state_mutex) != 0) {
			continue;
		}

		BeginDrawing();
		ClearBackground(state.background);

		state.cursor = MOUSE_CURSOR_DEFAULT;

		switch (client.conn_state) {
			case CLIENT_CONN_STATE_CONNECTING:
				// TODO: show proper message
				DrawText("connecting...", 0, 0, 30, BLACK);
				break;
			case CLIENT_CONN_STATE_ERROR:
				// TODO: show proper message
				DrawText("error", 0, 0, 30, BLACK);
				break;
			case CLIENT_CONN_STATE_READY:
				bool is_shift = IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT);
				if (IsKeyPressed(KEY_TAB) && is_shift) {
					state_prev_page(&state);
				} else if (IsKeyPressed(KEY_TAB)) {
					state_next_page(&state);
				}

				switch (state.page) {
					case PAGE_PLAYER:
						player_page_draw(&player, &client, &state);
						break;
					case PAGE_QUEUE:
						queue_page_draw();
						break;
				}
				break;
		}
		UNLOCK(&client.conn_state_mutex);

		SetMouseCursor(state.cursor);

		EndDrawing();
	}

	CloseWindow();

	client_free(&client);

	return 0;
}
