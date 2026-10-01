#+vet explicit-allocators

package mupwit

import "base:intrinsics"
import "core:container/queue"
import "core:log"

History_State :: enum {
	Normal = 0, // Clear all redos and push into the `undo` list.
	Undoing, // Push next commands into the `redo` list.
	Redoing, // Push next commands into the `undo` list.
}

// TODO!: limit the size of the history.
History :: struct {
	// `undo` and `redo` lists describe what command to execute to undo or redo
	// the change, they do not describe the previous state of the app.
	// TODO!: `Command_Set_Queue` should only contain the diff of the queue to
	// efficiently store and modify it.
	undo, redo: queue.Queue(Player_Command),
	_state:     History_State,
}

history_init :: proc(h: ^History, allocator := context.allocator) {
	queue.init(&h.undo, allocator = allocator)
	queue.init(&h.redo, allocator = allocator)
}

history_destroy :: proc(h: ^History) {
	_history_list_clear(&h.undo)
	_history_list_clear(&h.redo)
	queue.destroy(&h.undo)
	queue.destroy(&h.redo)
}

player_undo :: proc(player: ^Base_Player) -> bool {
	cmd := queue.pop_back_safe(&player.history.undo) or_return

	count := queue.len(player.history.undo)
	log.debugf("PLAYER: Undo, sending command %v, %v items left", cmd, count)

	player._req_flags.history_dont_push_next = true
	player.history._state = .Undoing
	_player_send(player, cmd)
	player.history._state = .Normal
	return true
}

player_redo :: proc(player: ^Base_Player) -> bool {
	cmd := queue.pop_back_safe(&player.history.redo) or_return

	count := queue.len(player.history.redo)
	log.debugf("PLAYER: Redo, sending command %v, %v items left", cmd, count)

	player._req_flags.history_dont_push_next = true
	player.history._state = .Redoing
	_player_send(player, cmd)
	player.history._state = .Normal
	return true
}

player_undo_count :: proc(player: ^Base_Player) -> int {
	return queue.len(player.history.undo)
}
player_redo_count :: proc(player: ^Base_Player) -> int {
	return queue.len(player.history.redo)
}

_player_history_push :: proc(player: ^Base_Player, cmd: Player_Command, loc := #caller_location) {
	undo, redo := &player.history.undo, &player.history.redo

	log.debugf("PLAYER: Push histroy: %v, state = %v", cmd, player.history._state)

	switch player.history._state {
	case .Normal:
		_history_list_clear(redo, loc)
		queue.push_back(undo, cmd, loc)
	case .Undoing:
		queue.push_back(redo, cmd, loc)
	case .Redoing:
		queue.push_back(undo, cmd, loc)
	}

	if queue.len(undo^) > HISTORY_LIMIT do queue.pop_front(undo)
	if queue.len(redo^) > HISTORY_LIMIT do queue.pop_front(redo)
}

_history_list_clear :: proc(list: ^queue.Queue(Player_Command), loc := #caller_location) {
	for i in 0 ..< queue.len(list^) {
		cmd := queue.get(list, i)
		_command_destroy(cmd, loc)
	}
	queue.clear(list)
}
