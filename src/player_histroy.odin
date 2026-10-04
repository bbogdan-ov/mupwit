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

Undo_Kind :: enum {
	None = 0,
	Song_Switch,
	Seek,
	Load,
	Load_Album,
	Queue_Remove,
	Queue_Add,
	Queue_Reorder,
	Queue_Shuffle,
	Queue_Clear,
}

@(rodata)
UNDO_KIND_NAME := [Undo_Kind]string {
	.None          = "",
	.Song_Switch   = "Song switch",
	.Seek          = "Seek current song",
	.Load          = "Load songs",
	.Load_Album    = "Load album",
	.Queue_Remove  = "Remove song",
	.Queue_Add     = "Add song",
	.Queue_Reorder = "Reorder song",
	.Queue_Shuffle = "Shuffle queue",
	.Queue_Clear   = "Clear queue",
}

Undo :: struct {
	command: Player_Command,
	kind:    Undo_Kind,
}

// TODO!: limit the size of the history.
History :: struct {
	// `undo` and `redo` lists describe what command to execute to undo or redo
	// the change, they do not describe the previous state of the app.
	// TODO!: `Command_Set_Queue` should only contain the diff of the queue to
	// efficiently store and modify it.
	undo, redo: queue.Queue(Undo),
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
	undo := queue.pop_back_safe(&player.history.undo) or_return

	count := queue.len(player.history.undo)
	log.debugf("PLAYER: Undid: %v, %v items left", undo.kind, count)

	player.history._state = .Undoing
	_player_send(player, undo.command)
	player.history._state = .Normal

	on_undid(undo.kind)
	return true
}

player_redo :: proc(player: ^Base_Player) -> bool {
	undo := queue.pop_back_safe(&player.history.redo) or_return

	count := queue.len(player.history.redo)
	log.debugf("PLAYER: Redid: %v, %v items left", undo.kind, count)

	player.history._state = .Redoing
	_player_send(player, undo.command)
	player.history._state = .Normal

	on_redid(undo.kind)
	return true
}

player_undo_count :: proc(player: ^Base_Player) -> int {
	return queue.len(player.history.undo)
}
player_redo_count :: proc(player: ^Base_Player) -> int {
	return queue.len(player.history.redo)
}

_player_history_push :: proc(
	player: ^Base_Player,
	kind: Undo_Kind,
	cmd: Player_Command,
	loc := #caller_location,
) {
	undo, redo := &player.history.undo, &player.history.redo

	log.debugf("PLAYER: Push histroy: %v, state = %v", cmd, player.history._state)

	switch player.history._state {
	case .Normal:
		_history_list_clear(redo, loc)
		queue.push_back(undo, Undo{cmd, kind}, loc)
	case .Undoing:
		queue.push_back(redo, Undo{cmd, kind}, loc)
	case .Redoing:
		queue.push_back(undo, Undo{cmd, kind}, loc)
	}

	if queue.len(undo^) > HISTORY_LIMIT do queue.pop_front(undo)
	if queue.len(redo^) > HISTORY_LIMIT do queue.pop_front(redo)
}

_player_history_push_queue :: proc(
	player: ^Base_Player,
	kind: Undo_Kind,
	loc := #caller_location,
) {
	cmd := cmd_make_load_from_songs(player, player.queue[:])
	cmd.play = player.cur_song
	cmd.seek = player.elapsed
	_player_history_push(player, kind, cmd, loc)
}

_history_list_clear :: proc(list: ^queue.Queue(Undo), loc := #caller_location) {
	for i in 0 ..< queue.len(list^) {
		undo := queue.get(list, i)
		_command_destroy(undo.command, loc)
	}
	queue.clear(list)
}
