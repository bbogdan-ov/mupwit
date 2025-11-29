#ifndef ACTION_H
#define ACTION_H

#define ACTIONS_QUEUE_CAP 16

typedef enum ActionKind {
	ACTION_TOGGLE = 1,
	ACTION_NEXT,
	ACTION_PREV,
	// Seek currently playing song
	// Data: `seek_seconds`
	ACTION_SEEK_SECONDS,

	// Data: `song_id`
	ACTION_PLAY_SONG,

	// Data: `reorder`
	ACTION_REORDER_QUEUE,

	// Close connection
	ACTION_CLOSE,
} ActionKind;

typedef struct Action {
	ActionKind kind;
	union {
		unsigned song_id;
		unsigned seek_seconds;

		struct {
			unsigned from;
			unsigned to;
		} reorder;
	} data;
} Action;

typedef struct ActionsQueue {
	size_t head;
	size_t tail;
	size_t cap;
	Action buffer[ACTIONS_QUEUE_CAP];
} ActionsQueue;

#endif
