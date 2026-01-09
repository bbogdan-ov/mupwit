package mpd

import "../util"
import "core:fmt"
import "core:image"

Cover_Data :: struct {
	image: ^image.Image,
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
	opts := image.Options{.do_not_expand_channels, .do_not_expand_grayscale}
	img, img_err := image.load_from_bytes(bytes[:], opts)
	if img_err != nil {
		panic(fmt.tprint("TODO: report the error and return an empty image:", img_err))
	}

	return Cover_Data{img}, nil
}

cover_destroy :: proc(cover: ^Cover_Data) {
	image.destroy(cover.image)
	cover.image = nil
}
