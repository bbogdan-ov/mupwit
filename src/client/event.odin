package client

// Client state changed
Event_State_Changed :: struct {
	state: State,
}

// Playback status received
Event_Status :: struct {
	status: Status,
}

// Song album cover received
Event_Cover :: struct {
	cover: Cover_Data,
}

Event :: union {
	Event_State_Changed,
	Event_Status,
	Event_Cover,
}
