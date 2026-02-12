package mpd

import "core:log"
import "core:strings"

import "../util"

Album :: struct {
	title:      Maybe(string),
	artist:     Maybe(string),
	first_song: Song,
}

album_destroy :: proc(album: ^Album) {
	song_destroy(&album.first_song)
	util.maybe_str_delete(album.title)
	util.maybe_str_delete(album.artist)
}

@(require_results)
request_albums :: proc(client: ^Client) -> (err: Error) {
	err = #force_inline _request_albums(client)
	if err != nil {
		log.error("CLIENT: Failed to request list of albums:", err)
	}
	return
}

@(private, require_results)
_request_albums :: proc(client: ^Client) -> (err: Error) {
	executef(client, "list album group artist") or_return // request all albums grouped by artists
	res := receive(client) or_return
	defer response_destroy(&res)

	albums := make([dynamic]Album, len = 0, cap = 32)

	// Slice from the response buffer
	cur_artist: Maybe(string) = nil

	// Fetch all albums.
	// The response will look like this:
	//     Artist: My cool artist
	//     Album: His cool album
	//     Album: Another album
	//     Album: Third album
	//     Artist: Yet another singer
	//     Album: And his album
	for {
		maybe_pair := response_next_pair(&res) or_return
		pair := maybe_pair.? or_break

		if pair.name == "Artist" {
			if len(pair.value) > 0 {
				cur_artist = pair.value
			} else {
				cur_artist = nil
			}
		} else if pair.name == "Album" {
			if len(pair.value) > 0 {
				artist: Maybe(string) = nil

				if a, ok := cur_artist.?; ok {
					artist = strings.clone(a)
				}

				album := Album {
					title  = strings.clone(pair.value),
					artist = artist,
				}
				append(&albums, album)
			}
		} else {
			log.errorf(
				"CLIENT: Unexpected pair while parsing albums list: %s => '%s'",
				pair.name,
				pair.value,
			)
			return .Unexpected_Pair
		}
	}

	// Fetch the first song of each album
	for &album in albums {
		CMD :: `find "((Album == %s) AND (Artist == %s))" window 0:1`
		title := util.espace(util.quote(album.title.? or_else ""))
		artist := util.espace(util.quote(album.artist.? or_else ""))
		executef(client, CMD, title, artist) or_return

		res := receive(client) or_return
		defer response_destroy(&res)
		maybe_song := response_next_song(client, &res) or_return
		song, ok := maybe_song.?
		if !ok {
			log.errorf(
				"CLIENT: Failed to request the first song of the album '%s' by '%s'",
				album.title,
				album.artist,
			)
			return .Response_Expected_Song_Info
		}

		album.first_song = song
	}

	_send_event(client, Event_Albums{albums})
	return nil
}
