package mpd

Action_Play :: struct {}
Action_Pause :: struct {}

// Request song album cover
Action_Req_Cover :: struct #all_or_none {
	id:       int,
	song_uri: string,
}

Action_Req_Albums :: struct {}

Action :: union #no_nil {
	Action_Play,
	Action_Pause,
	Action_Req_Cover,
	Action_Req_Albums,
}
