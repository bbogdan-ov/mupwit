#include <stdio.h>
#include <raylib.h>
#include <assert.h>

#include "client.h"
#include "player.h"
#include "state.h"
#include "tabs/player_tab.h"
#include "macros.h"
#include "theme.h"

// TODO: set mouse cursor to pointer when hovering over interactive things.
// For some FUCKING reason `SetMouseCursor` writes into some random ass memory
// address (without causing a segfault) that causes some data (specifically
// playback status data `player.cur_status`) to contain garbage number for ONLY
// ONE FUCKING FRAME and after this frame everything gets normal. May be i
// don't understand something?

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

		switch (client.conn_state) {
			case CLIENT_CONN_STATE_CONNECTING:
				DrawText("connecting...", 0, 0, 30, BLACK);
				break;
			case CLIENT_CONN_STATE_ERROR:
				DrawText("error", 0, 0, 30, BLACK);
				break;
			case CLIENT_CONN_STATE_READY:
				player_tab_draw(&player, &client, &state);
				break;
		}
		UNLOCK(&client.conn_state_mutex);

		EndDrawing();
	}

	CloseWindow();

	client_free(&client);

	return 0;
}
