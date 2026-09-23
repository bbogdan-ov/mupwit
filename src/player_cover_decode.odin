#+vet explicit-allocators

package mupwit

import "core:math/linalg"
import "core:thread"
import "core:time"
import "lib:ui"
import "vendor:stb/image"

import "lib:cairo"
import "lib:mpd"

_Cover_Thread_Data :: struct {
	responses: Responses_Chan,
	key:       Cover_Key,
	size:      Cover_Size,
	picture:   mpd.Picture,
}

// Decode a cover from a picture data on a separate thread.
// After successfull decoding sends a response.
_cover_decode_and_send :: proc(
	shared: ^Player_Shared,
	key: Cover_Key,
	size: Cover_Size,
	picture: mpd.Picture,
) {
	alloc := shared.allocator

	data := new(_Cover_Thread_Data, alloc)
	data.responses = shared.responses
	data.key = cover_key_clone(key, alloc)
	data.size = size
	data.picture = picture

	{
		mutex := &shared.covers_thread_pool
		pool := mutex_lock(mutex)
		defer mutex_unlock(mutex)

		// Delete all completed tasks.
		for _ in thread.pool_pop_done(pool) {}
		thread.pool_add_task(pool, alloc, _do_decode_cover, data)
	}
}

_do_decode_cover :: proc(task: thread.Task) {
	data := cast(^_Cover_Thread_Data)task.data
	defer {
		mpd.picture_destroy(data.picture)
		free(data, task.allocator)
	}

	total_start := time.now()

	// Decode image pixel data.
	decode_start := time.now()
	pixels, size := _decode_cover_image(data.picture.data)
	decode_time := time.since(decode_start)

	wanted_size := COVER_SIZE[data.size]

	// Create and resize cover surface.
	resize_start := time.now()
	surface := _create_cover_surface(pixels, size, wanted_size)
	image.image_free(pixels)
	resize_time := time.since(resize_start)

	color: Color
	if data.size > .Small {
		color = _calc_surface_accent_color(surface)
	}

	res := Response_Cover {
		key       = data.key, // already cloned with `task.allocator`.
		size      = data.size,
		surface   = surface,
		color     = color,
		allocator = task.allocator,
	}
	_response_send(data.responses, res)

	_ = total_start
	_ = decode_time
	_ = resize_time

	// TODO: log timings.
	// Disabled for now because Odin for some reason doesn't properly allocate
	// on the temp allocator inside task procs and sanitizer doesn't like this.
	//
	// log.debugf(
	// 	"Decoded and created song cover in total of %v, decoded in %v, resized in %v",
	// 	time.since(total_start),
	// 	decode_time,
	// 	resize_time,
	// )
}

_decode_cover_image :: proc(data: []u8) -> (pixels: [^]u8, size: Vec2) {
	// NOTE: we are assuming that this function ALWAYS returns RGBA pixel data
	// because we specified the exact number of channels in the `desired_channels`
	// argument. STB image seems to guarantee that.
	p := image.load_from_memory(
		raw_data(data),
		i32(len(data)),
		&size.x,
		&size.y,
		nil,
		COVER_CHANNELS,
	)
	assert(p != nil) // TODO: handle error.

	// RGBA -> BGRA because Cairo's pixel data layout requirements are
	// strange, but i don't complain.
	count := size.x * size.y * COVER_CHANNELS
	for i: i32; i < count; i += COVER_CHANNELS {
		b := p[i + 0]
		p[i + 0] = p[i + 2]
		p[i + 2] = b
	}

	pixels = p
	return
}

_create_cover_surface :: proc(pixels: [^]u8, size, wanted_size: Vec2) -> ^cairo.surface_t {
	stride := size.x * COVER_CHANNELS
	original := cairo.image_surface_create_for_data(pixels, .ARGB32, size.x, size.y, stride)
	defer cairo.surface_destroy(original)

	surface := cairo.image_surface_create(.ARGB32, wanted_size.x, wanted_size.y)
	cr := cairo.create(surface)
	defer cairo.destroy(cr)

	cairo.scale(cr, f64(wanted_size.x) / f64(size.x), f64(wanted_size.y) / f64(size.y))
	cairo.set_source_surface(cr, original, 0, 0)
	cairo.pattern_set_filter(cairo.get_source(cr), COVER_SCALE_FILTER)
	cairo.paint(cr)

	return surface
}

_calc_surface_accent_color :: proc(surface: ^cairo.surface_t) -> Color {
	assert(surface != nil)

	format := cairo.image_surface_get_format(surface)
	assert(format == .ARGB32)
	p := cairo.image_surface_get_data(surface)
	width := int(cairo.image_surface_get_width(surface))
	height := int(cairo.image_surface_get_height(surface))
	pixel_count := width * height * COVER_CHANNELS

	final: [4]f64
	final.a = 1
	total_factor: f64

	edge_h := f64(width) * 0.1
	edge_v := f64(height) * 0.1
	left, top := edge_h, edge_v
	right, bottom := f64(width) - edge_h, f64(height) - edge_v

	for i := 0; i < pixel_count; i += COVER_CHANNELS {
		rgb: [3]f64
		rgb.r = f64(p[i + 2]) / 255
		rgb.g = f64(p[i + 1]) / 255
		rgb.b = f64(p[i + 0]) / 255
		x, y := f64(i % width), f64(i / width)

		lum := rgb.r * 0.299 + rgb.g * 0.587 + rgb.b * 0.114
		factor := lum

		// Bright pixels near the edges affect the final color more.
		add: f64
			// odinfmt:disable
		switch {
		case x < left:   add = (left - x) / edge_h
		case x > right:  add = (x - right) / edge_h
		case y < top:    add = (top - y) / edge_v
		case y > bottom: add = (y - bottom) / edge_v
		}
		// odinfmt:enable
		factor += add * lum * 0.25

		factor = min(factor, 1)
		final.rgb += rgb * factor
		total_factor += factor
	}

	if total_factor <= 10.0 {
		return {}
	}

	final /= total_factor

	hsl := linalg.vector4_rgb_to_hsl(final)
	hue, sat, light := hsl[0], hsl[1], hsl[2]

	if light < 0.7 {
		// Dark becomes lighter.
		light += (1.0 - light) * 0.4
	}
	if sat > 0.7 {
		// Too saturated becomes less saturated and more lighter.
		sat *= 0.8
		light += sat * 0.25
	}
	light += (1.0 - light) * 0.2 // Final dark becomes lighter.
	sat = clamp(sat, 0, 1)
	light = clamp(light, 0, 1)

	if light < 0.5 {
		// Color is still too dark.
		return {}
	}

	final = linalg.vector4_hsl_to_rgb(hue, sat, light, 1)
	color := ui.color_from_f64(final)
	return color
}
