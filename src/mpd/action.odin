package mpd

Action_Play :: struct {}
Action_Pause :: struct {}

// Request a song in the queue by its id
Action_Req_Queue_Song :: struct {
	id: uint,
}

// Request song album cover
Action_Req_Cover :: struct {
	song_uri: string,
}

Action :: union #no_nil {
	Action_Play,
	Action_Pause,
	Action_Req_Queue_Song,
	Action_Req_Cover,
}
