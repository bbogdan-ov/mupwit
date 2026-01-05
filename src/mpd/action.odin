package mpd

Action_Play :: struct {}
Action_Pause :: struct {}

// Request song album cover
Action_Req_Cover :: struct {
	song_uri: string,
}

Action :: union #no_nil {
	Action_Play,
	Action_Pause,
	Action_Req_Cover,
}
