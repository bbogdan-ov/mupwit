package loop

Action_Play :: struct {}
Action_Pause :: struct {}
Action_Req_Status :: struct {}

Action :: union #no_nil {
	Action_Play,
	Action_Pause,
	Action_Req_Status,
}
