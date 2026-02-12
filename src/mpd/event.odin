package mpd

// Client state changed
Event_State_Changed :: struct {
	state: State,
}

Event_Status :: struct {
	status: Status,
}

Event_Status_And_Song :: struct #all_or_none {
	status: Status,
	// Currently playing song changed as well as the current status.
	// When `nil`, no sogn is currently being played for some reason (e.g. no more songs to play).
	song:   Maybe(Song),
}

// Song album cover received
Event_Cover :: struct #all_or_none {
	id:    int,
	cover: Cover_Data,
}

Event_Albums :: struct {
	albums: [dynamic]Album,
}

Event_Queue :: struct {
	songs: [dynamic]Song,
}

Event :: union {
	Event_State_Changed,
	Event_Status,
	Event_Status_And_Song,
	Event_Cover,
	Event_Albums,
	Event_Queue,
}
