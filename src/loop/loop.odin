package loop

import "core:container/queue"
Event_Loop :: struct {
	events:  [dynamic]Event,
	actions: queue.Queue(Action),
}

create :: proc() -> ^Event_Loop {
	loop := new(Event_Loop)
	queue.init(&loop.actions)
	return loop
}

push_event :: proc(loop: ^Event_Loop, event: Event) {
	append(&loop.events, event)
}
pop_event :: proc(loop: ^Event_Loop) -> Event {
	if len(loop.events) == 0 {return nil}
	event := pop(&loop.events)
	return event
}

push_action :: proc(loop: ^Event_Loop, action: Action) {
	queue.push_back(&loop.actions, action)
}
pop_action :: proc(loop: ^Event_Loop) -> Maybe(Action) {
	if queue.len(loop.actions) == 0 {return nil}
	action := queue.pop_back(&loop.actions)
	return action
}
