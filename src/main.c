#include <stdio.h>
#include <raylib.h>
#include <assert.h>
#include <errno.h>
#include <unistd.h>

#define __USE_POSIX
#include <signal.h>

#include "client.h"
#include "state.h"
#include "macros.h"
#include "theme.h"
#include "draw.h"
#include "pages/player_page.h"
#include "pages/queue_page.h"

static const char *PID_FILE = "/tmp/mupwit.pid";

// TODO: staticaly link with `libmpdclient` and maybe `raylib`
// TODO: add ability to undo actions like queue reordering or song selection

static volatile bool should_restore = false;

// Try to find for /tmp/mupwit.pid and if present, return true and
// send a custom signal to restore it's visibility state
// If something went wrong, return false
bool restore_previous(void) {
	FILE *file = fopen(PID_FILE, "r");
	if (file == NULL) return false;

	fseek(file, 0, SEEK_END);
	size_t file_size = ftell(file);
	fseek(file, 0, SEEK_SET);

	char buffer[24] = {0}; // enough to store 64 bit unsigned int
	fread(buffer, 1, MIN(24, file_size), file);
	if (ferror(file) != 0) goto error;

	errno = 0;
	long pid = strtol(buffer, NULL, 10);
	if (errno != 0) {
		pid = 0;
		goto error;
	}

	// Send SIGUSR1 to restore window visibility state
	if (kill(pid, SIGUSR1) != 0) {
		goto no_pid;
	}

	fclose(file);
	TraceLog(LOG_INFO, "Restored previously opened window (PID = %d)", pid);
	return true;

error:
	fclose(file);
	TraceLog(LOG_ERROR, "Something went wrong while trying to restore the window (PID = %d)", pid);
	return false;

no_pid:
	fclose(file);
	TraceLog(
		LOG_WARNING,
		"%s file is present but no program with this PID was found, "
		"deleting this file (PID = %d)",
		PID_FILE,
		pid
	);

	if (remove(PID_FILE) != 0)
		TraceLog(LOG_ERROR, "Unable to delete %s file", PID_FILE);

	return false;
}

void save_pid(void) {
	FILE *file = fopen(PID_FILE, "w");
	if (file == NULL) {
		TraceLog(LOG_ERROR, "Unable to save PID into %s", PID_FILE);
		return;
	}

	pid_t pid = getpid();

	char buffer[24] = {0}; // enough to store 64 bit unsigned int
	int nbytes = sprintf(buffer, "%d", pid);
	if (nbytes <= 0) goto defer;

	fwrite(buffer, 1, nbytes, file);
	if (ferror(file) != 0) goto defer;

	fclose(file);
	TraceLog(LOG_INFO, "Saved PID into %s (PID = %d)", PID_FILE, pid);
	return;

defer:
	fclose(file);
	TraceLog(LOG_ERROR, "Something went wrong while trying to store PID (PID = %d)", pid);
	return;
}

void handle_signal(int sig) {
	should_restore = sig == SIGUSR1;
}
void catch_signal(void) {
	if (signal(SIGUSR1, handle_signal) == SIG_ERR) {
		TraceLog(LOG_WARNING, "Unable to catch SIGUSR1, do nothing");
	}
}

int main() {
#if defined(__linux__) && defined(RELEASE)
	// TODO: allow disabling previous window restoring via cli args
	bool restored = restore_previous();
	if (restored > 0) {
		return 0;
	}

	save_pid();

	catch_signal();
#endif

#ifdef RELEASE
	SetTraceLogLevel(LOG_WARNING);
#endif

	InitWindow(THEME_WINDOW_WIDTH, THEME_WINDOW_HEIGHT, "MUPWIT");
	SetTargetFPS(60);

	Client client = client_new();
	client_connect(&client);

	State state = state_new();

	QueuePage queue_page = queue_page_new();

	while (true) {

#if defined(__linux__) && defined(RELEASE)
		if (WindowShouldClose() && !IsWindowState(FLAG_WINDOW_HIDDEN)) {
			printf("INFO: Window hidden, waiting for SIGUSR1 to show it again...\n");
			SetWindowState(FLAG_WINDOW_HIDDEN);
		}

		if (should_restore) {
			if (IsWindowState(FLAG_WINDOW_HIDDEN)) {
				printf("INFO: Window restored due received SIGUSR1\n");
				ClearWindowState(FLAG_WINDOW_HIDDEN);
			}

			catch_signal();
			should_restore = false;
		}
#else
		if (WindowShouldClose()) break;
#endif

		LOCK(&client.conn_mutex);
		ClientConnState conn_state = client.conn_state;
		UNLOCK(&client.conn_mutex);

		if (conn_state == CLIENT_CONN_STATE_READY) {
			bool is_shift = is_shift_down();
			if (is_key_pressed(KEY_TAB) && is_shift) {
				state_prev_page(&state);
			} else if (is_key_pressed(KEY_TAB)) {
				state_next_page(&state);
			}

			client_update(&client, &state);
			state_update(&state);

			queue_page_update(&queue_page, &client);
		}

		BeginDrawing();

#if defined(__linux__) && defined(RELEASE)
		// Do not draw the UI if window is hidden
		if (IsWindowState(FLAG_WINDOW_HIDDEN)) {
			// It will update every second instead of 60 times per second so we
			// don't waste CPU resources
			sleep(1);

			// NOTE: we still calling BeginDrawing() and EndDrawing() because
			// it is essential to things like GetFrameTime() to work
			EndDrawing();
			continue;
		}
#endif

		ClearBackground(state.background);

		state.container = screen_rect();
		state.cursor = MOUSE_CURSOR_DEFAULT;

		switch (conn_state) {
			case CLIENT_CONN_STATE_CONNECTING:
				// TODO: show proper message
				DrawText("connecting...", 0, 0, 30, BLACK);
				break;
			case CLIENT_CONN_STATE_ERROR:
				// TODO: show proper message
				DrawText("error", 0, 0, 30, BLACK);
				break;
			case CLIENT_CONN_STATE_READY:
				player_page_draw(&client, &state);
				queue_page_draw(&queue_page, &client, &state);
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
