#+vet explicit-allocators

package mpd

import "core:log"
import "core:time"

@(require_results)
request_changes :: proc(
	client: ^Client,
	loc := #caller_location,
) -> (
	changes: Changes,
	err: Error,
) {
	send(client, "idle", loc = loc) or_return
	send(client, "noidle", loc = loc) or_return

	parser := recv_and_parse(client, context.allocator, loc) or_return
	defer parser_destroy(parser, context.allocator)

	changes, _ = parser_next_changes(&parser)
	return changes, nil
}

@(require_results)
request_status :: proc(client: ^Client, loc := #caller_location) -> (status: Status, err: Error) {
	send(client, "status", loc = loc) or_return
	parser := recv_and_parse(client, context.allocator, loc) or_return
	defer parser_destroy(parser, context.allocator)

	found: bool
	status, found = parser_next_status(&parser)
	if !found {
		panic("TODO: handle missing status")
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

	send(client, "playlistid", loc = loc) or_return
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
		send(client, "readpicture", file, offset, loc = loc) or_return

		s := recv(client, allocator) or_return
		defer delete(s, allocator)

		parser := parser_make(s)
		found: bool

		if offset == 0 {
			picture, found = parser_next_picture_info(&parser, allocator)
			if !found {
				log.debugf("MPD: Picture is missing for %q", file)
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
			log.errorf("MPD: For %q", file)
			log.errorf("MPD: %s", parser.s)
			panic("TODO!!!: handle missing picture binary")
		}

		assert(offset + len(part) <= len(picture.data))
		copy_slice(picture.data[offset:][:len(part)], part)

		offset += len(part)

		if offset >= len(picture.data) {
			break
		}
	}

	log.debugf("MPD: Received picture info in %v for %q", time.since(start), file)

	return picture, false, nil
}
