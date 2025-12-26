package client

Action_Play :: struct {}
Action_Pause :: struct {}

// Request current playback status
Action_Req_Status :: struct {}
// Request song album cover
Action_Req_Cover :: struct {
	song_uri: string,
}

Action :: union #no_nil {
	Action_Play,
	Action_Pause,
	Action_Req_Status,
	Action_Req_Cover,
}
