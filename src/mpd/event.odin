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

// Client closed the connection
Event_Closed :: struct {}

Event :: union {
	Event_State_Changed,
	Event_Status,
	Event_Status_And_Song,
	Event_Cover,
	Event_Albums,
	Event_Closed,
}
