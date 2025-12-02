#ifndef EVENT_H
#define EVENT_H

#define EVENTS_QUEUE_CAP 16

typedef enum EventKind {
	EVENT_NONE = 0,

	// Half of second has passed
	EVENT_ELAPSED,
	// Playback status chagned (pause, resume, seek, etc...)
	EVENT_STATUS_CHANGED,
	// Currently playing song was changed
	EVENT_SONG_CHANGED,
	// Current queue was changed outside MUPWIT (something else made queue to change)
	// Data: `queue`
	EVENT_QUEUE_CHANGED,
	EVENT_DATABASE_CHANGED,

	// Response received
	// Data: `response_artwork`
	EVENT_RESPONSE,
} EventKind;

typedef struct EventDataQueue {
	// List MPD queue entities/songs
	// Type is guaranteed to be `MPD_ENTITY_TYPE_SONG`
	struct mpd_entity **items;
	size_t len;
	size_t cap;
} EventDataQueue;

typedef struct Event {
	EventKind kind;
	union {
		EventDataQueue queue;

		struct {
			int id;
			Image image;
			Color color;
		} response_artwork;
	} data;
} Event;

typedef struct EventsQueue {
	size_t head;
	size_t tail;
	size_t cap;
	Event buffer[EVENTS_QUEUE_CAP];
} EventsQueue;

#endif
