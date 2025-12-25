package loop

import "base:builtin"
import "core:container/queue"
import "core:sync"

Event_Loop :: struct {
	events:        [dynamic]Event,
	events_mutex:  sync.Mutex,
	actions:       queue.Queue(Action),
	actions_mutex: sync.Mutex,
}

make :: proc() -> ^Event_Loop {
	loop := new(Event_Loop)
	loop.events = builtin.make([dynamic]Event)
	queue.init(&loop.actions)
	return loop
}

destroy :: proc(loop: ^Event_Loop) {
	queue.destroy(&loop.actions)
	delete(loop.events)
	free(loop)
}

push_event :: proc(loop: ^Event_Loop, event: Event) {
	sync.guard(&loop.events_mutex)
	append(&loop.events, event)
}
pop_event :: proc(loop: ^Event_Loop) -> Event {
	sync.guard(&loop.events_mutex)
	if len(loop.events) == 0 {return nil}
	event := pop(&loop.events)
	return event
}

push_action :: proc(loop: ^Event_Loop, action: Action) {
	sync.guard(&loop.actions_mutex)
	queue.push_back(&loop.actions, action)
}
pop_action :: proc(loop: ^Event_Loop) -> Maybe(Action) {
	sync.guard(&loop.actions_mutex)
	if queue.len(loop.actions) == 0 {return nil}
	action := queue.pop_back(&loop.actions)
	return action
}
