#+vet explicit-allocators

package mpd

import "core:fmt"
import "core:log"
import "core:strings"
import "core:time"

Command_Builder :: strings.Builder

// Formats a MPD filter for a tag: `(<tag> == "<str>")`.
tag_filter_make :: proc(tag, str: string, allocator := context.allocator) -> string {
	write :: strings.write_string

	sb := strings.builder_make(allocator)
	write(&sb, "(")
	write(&sb, tag)
	write(&sb, " == ")
	write_quoted_string(&sb, str)
	write(&sb, ")")
	return strings.to_string(sb)
}

cmd_begin :: proc(cmd: string, allocator := context.allocator) -> Command_Builder {
	sb := strings.builder_make(allocator)
	strings.write_string(&sb, cmd)
	return sb
}
cmd_push_string :: proc(cmd: ^Command_Builder, str: string) {
	strings.write_byte(cmd, ' ')
	strings.write_string(cmd, str)
}
cmd_push_quoted :: proc(cmd: ^Command_Builder, str: string) {
	strings.write_byte(cmd, ' ')
	write_quoted_string(cmd, str)
}
cmd_push_int :: proc(cmd: ^Command_Builder, n: int) {
	strings.write_byte(cmd, ' ')
	strings.write_int(cmd, n)
}
cmd_push_tag_filter :: proc(cmd: ^Command_Builder, tag, str: string) {
	filter := tag_filter_make(tag, str, cmd.buf.allocator)
	defer delete(filter, cmd.buf.allocator)
	cmd_push_quoted(cmd, filter)
}
cmd_end :: proc(cmd: ^Command_Builder) -> string {
	strings.write_byte(cmd, '\n')
	return strings.to_string(cmd^)
}
cmd_destroy :: proc(cmd: ^Command_Builder) {
	strings.builder_destroy(cmd)
}
cmd_send :: proc(client: ^Client, cmd: ^Command_Builder, loc := #caller_location) -> Error {
	str := cmd_end(cmd)
	err := _send_string(client, str, loc)
	cmd_destroy(cmd)
	return err
}

@(require_results)
request_changes :: proc(
	client: ^Client,
	loc := #caller_location,
) -> (
	changes: Changes,
	err: Error,
) {
	send_const(client, "idle", loc) or_return
	send_const(client, "noidle", loc) or_return

	parser := recv_and_parse(client, context.allocator, loc) or_return
	defer parser_destroy(parser, context.allocator)

	changes, _ = parser_next_changes(&parser)
	return changes, nil
}

@(require_results)
request_status :: proc(client: ^Client, loc := #caller_location) -> (status: Status, err: Error) {
	send_const(client, "status", loc) or_return
	parser := recv_and_parse(client, context.allocator, loc) or_return
	defer parser_destroy(parser, context.allocator)

	found: bool
	status, found = parser_next_status(&parser)
	if !found {
		log.error("MPD: Missing status response", location = loc)
		log.errorf("MPD: Received string:\n---\n%s\n---", parser.s, location = loc)
		err = .Missing_Response
		return
	}

	return status, nil
}

@(require_results)
request_queue :: proc(
	client: ^Client,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	queue: Song_List,
	err: Error,
) {
	start := time.now()

	send_const(client, "playlistid", loc) or_return
	parser := recv_and_parse(client, allocator, loc) or_return
	defer parser_destroy(parser, allocator)

	// TODO!: do not rebuild the whole queue but only songs that changed.
	parse_start := time.now()
	queue = make(Song_List, len = 0, cap = 64, allocator = allocator)
	for song in parser_next_song(&parser, allocator) {
		append(&queue, song)
	}

	log.debugf(
		"MPD: Received queue of %v songs in %v, parsed in %v",
		len(queue),
		time.since(start),
		time.since(parse_start),
		location = loc,
	)

	return queue, nil
}

request_song_picture :: proc(
	client: ^Client,
	file: Song_File,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	picture: Picture,
	missing: bool,
	err: Error,
) {
	assert(len(file) > 0)

	start := time.now()
	offset: int

	for {
		// TODO: may be i should first try to request a cover image using
		// `albumart` and if it fails use `readpicture`?
		// Because some users may prefer to store cover images as standalone
		// files in a dir with songs rather than embedding covers into song
		// files instead.
		cmd := cmd_begin("readpicture", context.allocator)
		cmd_push_quoted(&cmd, string(file))
		cmd_push_int(&cmd, offset)
		cmd_send(client, &cmd, loc) or_return

		s := recv(client, allocator) or_return
		defer delete(s, allocator)

		parser := parser_make(s)
		found: bool

		if offset == 0 {
			picture, found = parser_next_picture_info(&parser, allocator)
			if !found {
				log.debugf("MPD: Picture is missing for %q", file, location = loc)
				missing = true
				err = nil
				return
			}

			picture.data = make([]u8, picture.data_size, allocator)
		} else {
			parser_skip_until_pair(&parser, "binary")
		}

		part: []u8
		part, found = parser_next_binary(&parser, loc)
		if !found {
			log.errorf("MPD: Missing picture binary response for %q", file, location = loc)
			log.errorf("MPD: Received string:\n---\n%s\n---", parser.s, location = loc)
			err = .Missing_Response
			return
		}

		assert(offset + len(part) <= len(picture.data))
		copy_slice(picture.data[offset:][:len(part)], part)

		offset += len(part)

		if offset >= len(picture.data) {
			break
		}
	}

	log.debugf("MPD: Received picture info in %v for %q", time.since(start), file, location = loc)

	return picture, false, nil
}

request_albums :: proc(
	client: ^Client,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	albums: Album_List,
	err: Error,
) {
	start := time.now()

	send_const(client, "listallinfo", loc) or_return
	parser := recv_and_parse(client, context.allocator, loc) or_return
	defer parser_destroy(parser, context.allocator)

	albums = make(Album_List, allocator)

	cur_album: string
	cur_artist: string
	album: Album

	@(static) first := true

	// TODO: `parser_next_song` should not probably allocate song right away,
	// instead it should return song with strings sliced from the parser's
	// string and then the user of this function can decide when to clone this
	// song into the heap.
	for song in parser_next_song(&parser, allocator, loc) {
		if first && len(song.file) == 0 {
			fmt.println("-----")
			fmt.printfln("offset: %v, %v", parser.offset, len(parser.s))
			fmt.println("-----")
			fmt.println(parser.s[parser.offset:])
			fmt.println("-----")
			fmt.println(parser.s)
			fmt.println("-----")
			first = false
		}

		if len(song.album) == 0 {
			song_destroy(song)
			continue
		}

		if song.album != cur_album || song.artist != cur_artist {
			if album.songs != nil && len(album.songs) > 0 {
				append(&albums, album)
			}

			album = {}
			album.songs = make(Song_List, allocator)
			cur_album = song.album
			cur_artist = song.artist
		}

		append(&album.songs, song)
	}

	if album.songs != nil && len(album.songs) > 0 {
		append(&albums, album)
	}

	log.debugf(
		"MPD: Received album list of %v albums in %v",
		len(albums),
		time.since(start),
		location = loc,
	)

	return albums, nil
}
