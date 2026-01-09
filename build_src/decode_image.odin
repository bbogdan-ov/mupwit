package build

import "core:fmt"
import "core:image/png"
import "core:os"

decode_png :: proc(assets_file: os.Handle, name: string, channels: int) -> (ok: bool) {
	path := fmt.aprintf(IMAGES_URI + "%s.png", name)
	defer delete(path)

	image, err := png.load(path, png.Options{.do_not_expand_grayscale, .do_not_expand_channels})
	if err != nil {
		fmt.eprintfln("Unable to load PNG image %s: %s", path, err)
		return
	}
	defer png.destroy(image)

	if image.channels != channels {
		MSG :: "Expected %d number of channels, got %d for %s"
		fmt.eprintfln(MSG, channels, image.channels, path)
		return
	}

	if image.depth != 8 {
		MSG :: "Only depth of %d bits is supported, got %d for %s"
		fmt.eprintfln(MSG, 8, image.depth, path)
		return
	}

	{
		// Write raw image data
		outpath := fmt.aprintf(BUILD_IMAGES_URI + "%s.rawimage.bin", name)
		file := create_file(outpath) or_return
		_, err := os.write(file, image.pixels.buf[:])
		if err != nil {
			fmt.eprintln("Unable to write decoded raw image data:", err)
			return
		}

		os.flush(file)
		os.close(file)
	}

	{
		// Write image info and helper functions

		format: string
		switch image.channels {
		case 1:
			format = "UNCOMPRESSED_GRAYSCALE"
		case 2:
			format = "UNCOMPRESSED_GRAY_ALPHA"
		case 3:
			format = "UNCOMPRESSED_R8G8B8"
		case 4:
			format = "UNCOMPRESSED_R8G8B8A8"
		case:
			fmt.eprintfln("Unhandled number of channels (%d) for %s", image.channels, path)
			return
		}

		f := assets_file
		putline(f, "image_load_%s :: proc() -> ui.Texture {{", name)
		putline(f, "\t// Image should not be freed because it's data is static.")
		putline(f, "\tpixels := #load(\"images/%s.rawimage.bin\")", name)
		putline(f, "")
		putline(
			f,
			"\treturn ui.load_texture(pixels, %d, %d, .%s, 1)",
			image.width,
			image.height,
			format,
		)
		putline(f, "}}")
	}

	return true
}
