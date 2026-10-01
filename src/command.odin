#+vet explicit-allocators

//
// Commands do something with MUPWIT, resume/pause the playback, shuffle the
// queue, close the window, etc. Yeah, just like VIM commands or commands from
// "command palettes" in some modern apps.
//
// Not to confuse with `Player_Command`.
//

package mupwit

import "base:runtime"
import "core:reflect"
import "core:strings"

import win "lib:my_window"

Command :: enum {
	None = 0,

	// Playback.
	Play,
	Pause,
	Toggle,
	Next,
	Previous,

	// App.
	Quit,
}

@(rodata)
COMMAND_DESCRIPTION := [Command]string {
	.None     = "",

	// Playback.
	.Play     = "Resume or start playback",
	.Pause    = "Pause playback",
	.Toggle   = "Pause or resume playback",
	.Next     = "Play the next song",
	.Previous = "Play the previous song",

	// App.
	.Quit     = "Quit MUPWIT",
}

Command_Binding :: struct {
	name:     string,
	alias_to: Maybe(string),
	command:  Command,
}

Commands :: struct {
	list:      [dynamic]Command_Binding,
	allocator: runtime.Allocator,
}

commands_init :: proc(cmds: ^Commands) {
	allocator := context.allocator

	cmds.list = make([dynamic]Command_Binding, 0, len(Command) + 10, allocator)
	cmds.allocator = allocator

	for cmd in Command {
		if cmd == .None do continue

		name := reflect.enum_field_names(Command)[cmd]
		command_define(cmds, name, cmd)
	}

	command_define(cmds, "prev", .Previous)
	command_define(cmds, "bye", .Quit)
	command_define(cmds, "q", .Quit)
}

commands_destroy :: proc(cmds: ^Commands) {
	for binding in cmds.list {
		delete(binding.name, cmds.allocator)
		delete(binding.alias_to.? or_else "", cmds.allocator)
	}
	delete(cmds.list)
}

command_define :: proc(cmds: ^Commands, name: string, cmd: Command) {
	binding: Command_Binding
	binding.name = strings.to_lower(name, cmds.allocator)
	binding.command = cmd

	real_name := reflect.enum_field_names(Command)[cmd]
	if !strings.equal_fold(real_name, binding.name) {
		binding.alias_to = strings.to_lower(real_name, cmds.allocator)
	}

	append(&cmds.list, binding)
}

command_find :: proc(cmds: ^Commands, name: string) -> (cmd: Command, ok: bool) {
	// Yep, it performs a linear search, there is not that many of commands, so
	// i'll be fine.
	for binding in cmds.list {
		if strings.equal_fold(binding.name, name) {
			return binding.command, true
		}
	}
	return .None, false
}

command_execute_from_name :: proc(state: ^State, name: string) -> (ok: bool) {
	cmd := command_find(&state.commands, name) or_return
	command_execute(state, cmd)
	return true
}

command_execute :: proc(state: ^State, cmd: Command) {
	player := state.player

	switch cmd {
	case .None: // Do nothing.

	case .Play:
		player_play_or_resume(player)
	case .Pause:
		player_pause(player)
	case .Toggle:
		player_toggle_play(player)
	case .Next:
		player_next(player)
	case .Previous:
		player_previous(player)

	case .Quit:
		win.set_should_close(state.window, true)
	}
}

command_icon :: proc(cmd: Command) -> (icon: Icon, ok: bool) {
	return {}, false
}
