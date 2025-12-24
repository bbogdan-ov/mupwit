package loop

Event_Client_Ready :: struct {}
Event_Client_Error :: struct {
	error: string,
}

Event :: union {
	Event_Client_Ready,
	Event_Client_Error,
}
