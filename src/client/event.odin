package client

// Client state changed
Event_State_Changed :: struct {
	state: State,
}

// Playback status received
Event_Status :: struct {
	status: Status,
}

Event :: union {
	Event_State_Changed,
	Event_Status,
}
