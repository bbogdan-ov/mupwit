package loop

// The client was been connected successfully
Event_Client_Ready :: struct {}
// Something went wrong while trying to connect the client
Event_Client_Error :: struct {}

Event :: union {
	Event_Client_Ready,
	Event_Client_Error,
}
