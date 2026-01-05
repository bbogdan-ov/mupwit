package mpd

// Client state changed
Event_State_Changed :: struct {
	state: State,
}

Event_Status :: struct {
	status: Status,
}

Event_Status_And_Song :: struct {
	status: Status,
	song:   Maybe(Song),
}

// Song album cover received
Event_Cover :: struct {
	cover: Cover_Data,
}

Event :: union {
	Event_State_Changed,
	Event_Status,
	Event_Status_And_Song,
	Event_Cover,
}
