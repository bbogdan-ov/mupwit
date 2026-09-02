package prebuild

import "base:runtime"
import "core:fmt"
import "core:image/png"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"

ASSETS_PATH :: "assets/"
IMAGES_PATH :: ASSETS_PATH + "images/"

REQUIRED_IMAGE_CHANNELS :: 4 // RGBA
REQUIRED_IMAGE_DEPTH :: 8 // 8-bit

main :: proc() {
	decode_images()
}

decode_images :: proc() {
	context.logger = log.create_console_logger()

	walker := os.walker_create(IMAGES_PATH)
	defer os.walker_destroy(&walker)

	for info in os.walker_walk(&walker) {
		if info.type != .Regular do continue
		if !strings.ends_with(info.name, ".png") do continue

		_ = decode_and_write_png(info.fullpath)
	}
}

// Decodes a raw ARGB (8 bits each component) pixel data of an image and writes
// it into `*.argb32` binary that is ready to be loaded right away into a Cairo
// surface.
@(require_results)
decode_and_write_png :: proc(path: string) -> (ok: bool) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	image, img_err := png.load(path, {.alpha_add_if_missing})
	if img_err != nil {
		log.errorf("Failed to load PNG image %q: %v", path, img_err)
		return false
	}

	if image.channels != REQUIRED_IMAGE_CHANNELS {
		MSG :: "Invalid number of channels of image %q: %v vs %v"
		log.errorf(MSG, path, image.channels, REQUIRED_IMAGE_CHANNELS)
		return false
	}
	if image.depth != REQUIRED_IMAGE_DEPTH {
		MSG :: "Invalid bit depth of image %q: %v vs %v"
		log.errorf(MSG, path, image.depth, REQUIRED_IMAGE_DEPTH)
		return false
	}

	stem := filepath.base(path)
	stem = filepath.stem(stem)

	output_path := fmt.tprintf(IMAGES_PATH + "%v.argb32", stem)

	output_file, err := os.open(output_path, {.Write, .Create, .Trunc})
	if err != nil {
		log.errorf("Failed to open output file for writing %q: %v", output_path, err)
		return false
	}

	output_data := make([]u8, len(image.pixels.buf), context.temp_allocator)

	// RGBA -> ARGB
	for i in 0 ..< image.width * image.height {
		output_data[i * 4 + 0] = image.pixels.buf[i * 4 + 3]
		output_data[i * 4 + 1] = image.pixels.buf[i * 4 + 0]
		output_data[i * 4 + 2] = image.pixels.buf[i * 4 + 1]
		output_data[i * 4 + 3] = image.pixels.buf[i * 4 + 2]
	}

	_, err = os.write(output_file, output_data)
	if err != nil {
		log.errorf("Failed to write to output file %q: %v", output_path, err)
		return false
	}

	return true
}
