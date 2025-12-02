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
	// Albums list was changed
	// Data: `albums`
	EVENT_ALBUMS_LIST_CHANGED,

	// Response received
	// Data: `response_artwork`
	EVENT_RESPONSE,
} EventKind;

typedef struct EventDataQueue {
	// List MPD queue entities/songs
	// Entities types are guaranteed to be `MPD_ENTITY_TYPE_SONG`
	DA_FIELDS(struct mpd_entity*)
} EventDataQueue;

typedef struct EventDataAlbumsList {
	DA_FIELDS(AlbumInfo)
} EventDataAlbumsList;

typedef struct Event {
	EventKind kind;
	union {
		EventDataQueue queue;
		EventDataAlbumsList albums;

		struct {
			int id;
			Image image;
			Color color;
		} response_artwork;
	} data;
} Event;

typedef struct EventsQueue {
	RINGBUF_FIELDS(Event, EVENTS_QUEUE_CAP)
} EventsQueue;

#endif
