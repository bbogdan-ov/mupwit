package mpd

import "vendor:raylib"

import "../util"

Cover_Data :: struct {
	image: raylib.Image,
}

request_cover :: proc(client: ^Client, song_uri: string) -> (cover: Cover_Data, err: Error) {
	offset := 0

	res: Response
	defer response_destroy(&res)

	bytes: [dynamic]byte = nil
	filetype: cstring = ".png"

	uri := util.quote(song_uri)

	for {
		executef(client, "readpicture %s %d", uri, offset) or_return

		response_destroy(&res) // free previous response
		res = receive(client) or_return

		// Parse `size` field
		pair := response_expect_pair(&res, "size") or_return
		size := pair_parse_int(pair) or_return

		// Allocate enough space for the image data
		if bytes == nil {
			bytes = make([dynamic]byte, len = size, cap = size)
		}

		// Parse `type` field
		pair = response_expect_pair(&res, "type") or_return
		switch pair.value {
		case "image/png":
			filetype = ".png"
		case "image/jpg":
			fallthrough
		case "image/jpeg":
			filetype = ".jpg"
		case "image/webp":
			filetype = ".webp"
		}

		// Parse binary
		b := response_next_binary(&res) or_return
		copy(bytes[offset:], b[:])
		offset += len(b)

		response_expect_ok(&res) or_return

		if offset >= len(bytes) do break
	}

	// Decode image data
	img := raylib.LoadImageFromMemory(filetype, raw_data(bytes), cast(i32)len(bytes))

	return Cover_Data{img}, nil
}

cover_destroy :: proc(cover: ^Cover_Data) {
	raylib.UnloadImage(cover.image)
	cover.image.data = nil
}
