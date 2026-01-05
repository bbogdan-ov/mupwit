package mpd

Action_Play :: struct {}
Action_Pause :: struct {}

// Request current playback status
Action_Req_Status :: struct {}

// Request current playback status and the current song
Action_Req_Song_And_Status :: struct {}

// Request a song in the queue by its id
Action_Req_Queue_Song :: struct {
	id: int,
}

// Request song album cover
Action_Req_Cover :: struct {
	song_uri: string,
}

Action :: union #no_nil {
	Action_Play,
	Action_Pause,
	Action_Req_Status,
	Action_Req_Song_And_Status,
	Action_Req_Queue_Song,
	Action_Req_Cover,
}
