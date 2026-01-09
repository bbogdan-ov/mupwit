package build

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"

import "../src/ui"

Bbx :: struct #all_or_none {
	width:  int,
	height: int,
	x:      int,
	y:      int,
}

bbx :: proc() -> Bbx {
	return Bbx{-1, -1, -1, -1}
}

Glyph :: struct #all_or_none {
	codepoint: rune,
	advance_x: int,
	bbx:       Bbx,
	// Glyph rect position relative to the texture's top-left corner.
	rect_pos:  [2]int,
	bitmap:    [dynamic]u32,
}

decode_bdf :: proc(assets_file: os.Handle, name: string) -> (ok: bool) {
	path := fmt.aprintf(FONTS_URI + "%s.bdf", name)
	defer delete(path)

	max_codepoint: rune = -1
	font_bbx := bbx()
	font_pixe_size := -1
	glyphs := make([dynamic]Glyph, len = 0, cap = 256)
	defer delete(glyphs)
	{
		// Parsing the BDF file and collect all the glyphs
		data, err := os.read_entire_file_from_filename_or_err(path)
		if err != nil {
			fmt.eprintfln("Unable to read font file %s: %s", path, err)
			return
		}

		text := string(data)
		defer delete(data)

		cur_glyph: Maybe(Glyph) = nil
		is_bitmap := false

		for line in strings.split_lines_iterator(&text) {
			parts := strings.split(line, " ")
			defer delete(parts)

			if glyph, ok := &cur_glyph.?; ok {
				if parts[0] == "ENDCHAR" {
					assert(is_bitmap)

					append(&glyphs, glyph^)

					cur_glyph = nil
					is_bitmap = false
				} else if parts[0] == "ENCODING" {
					assert(len(parts) >= 2)
					code := rune(parse_int(parts[1]).? or_return)
					max_codepoint = math.max(code, max_codepoint)
					glyph.codepoint = code
				} else if parts[0] == "DWIDTH" {
					assert(len(parts) >= 2)
					glyph.advance_x = parse_int(parts[1]).? or_return
					assert(glyph.advance_x >= 0)
				} else if parts[0] == "BBX" {
					assert(len(parts) >= 5)
					glyph.bbx.width = parse_int(parts[1]).? or_return
					glyph.bbx.height = parse_int(parts[2]).? or_return
					glyph.bbx.x = parse_int(parts[3]).? or_return
					glyph.bbx.y = parse_int(parts[4]).? or_return
					glyph.bbx.y -= font_pixe_size - glyph.bbx.height
				} else if parts[0] == "BITMAP" {
					is_bitmap = true
				} else if is_bitmap {
					assert(glyph.bbx.width >= 0)

					bits := u32(parse_int(line, 16).? or_return)

					if glyph.bbx.width <= 8 do assert(bits <= 255)
					else if glyph.bbx.width <= 16 do assert(bits <= 65535)

					append(&glyph.bitmap, bits)
				}
			} else if parts[0] == "STARTCHAR" {
				cur_glyph = Glyph {
					codepoint = -1,
					advance_x = -1,
					bbx       = bbx(),
					rect_pos  = {-1, -1},
					bitmap    = {},
				}
			} else if parts[0] == "FONTBOUNDINGBOX" {
				assert(len(parts) >= 5)
				font_bbx.width = parse_int(parts[1]).? or_return
				font_bbx.height = parse_int(parts[2]).? or_return
				font_bbx.x = parse_int(parts[3]).? or_return
				font_bbx.y = parse_int(parts[4]).? or_return
			} else if parts[0] == "PIXEL_SIZE" {
				assert(len(parts) >= 2)
				font_pixe_size = parse_int(parts[1]).? or_return
			}
		}
	}

	assert(glyphs[0].codepoint == 0)

	// NOTE: it is ok if `font_bbx.y` is < 0
	assert(font_bbx.x >= 0)
	assert(font_bbx.width > 0)
	assert(font_bbx.height > 0)

	assert(font_pixe_size > 0)

	// Render glyphs into the pixels buffer
	PADDING :: 1
	glyphs_width := font_bbx.width - font_bbx.x + PADDING
	glyphs_height := font_bbx.height - font_bbx.y + PADDING

	offset_y := 0

	cap := len(glyphs) * glyphs_width * glyphs_height * 2
	pixels := make([dynamic]byte, len = 0, cap = cap)

	// Render glyphs onto the pixels buffer
	for &glyph in glyphs {
		for row in glyph.bitmap {
			for col_idx := glyphs_width; col_idx > 0; col_idx -= 1 {
				b := (row << PADDING >> uint(col_idx)) & 1
				append(&pixels, 255, byte(b * 255)) // red, alpha
			}
		}

		// Add empty rows for padding
		for _ in 0 ..< glyphs_width * PADDING do append(&pixels, 255, 0)

		glyph.rect_pos.x = PADDING
		glyph.rect_pos.y = offset_y
		offset_y += glyph.bbx.height + PADDING
	}

	// Generate glyph map
	null_glyph := glyphs[0]

	all_glyphs := make([dynamic]Glyph, len = 0, cap = max_codepoint)
	defer delete(all_glyphs)

	// Fill glyph map with null characters
	for _ in 0 ..= max_codepoint {
		append(&all_glyphs, null_glyph)
	}
	for glyph in glyphs {
		assert(glyph.rect_pos.x >= 0)
		assert(glyph.rect_pos.y >= 0)

		all_glyphs[glyph.codepoint] = glyph
	}

	{
		// Write raw image data
		outpath := fmt.aprintf(BUILD_FONTS_URI + "%s.rawimage.bin", name)
		file := create_file(outpath) or_return

		_, err := os.write(file, pixels[:])
		if err != nil {
			fmt.eprintln("Unable to write decoded font raw image data:", err)
			return
		}

		os.flush(file)
		os.close(file)
	}

	// Glyphs info and rectangles are stored in a dirties way possible!!!
	// I literally write byte representation of the arrays (glyph info and
	// rectangles arrays) into the binary files, load these files in the app
	// and represent them back as arrays of structs.
	// I'm not even sure it this will work well on 32-bit and/or big endian machines.
	// Do not look at this code, rust people.

	{
		// Write glyphs info
		outpath := fmt.aprintf(BUILD_FONTS_URI + "%s.glyphs.bin", name)
		file := create_file(outpath) or_return

		for codepoint in 0 ..= max_codepoint {
			glyph := &all_glyphs[codepoint]

			advance_x_bytes := i32_to_bytes(i32(glyph.advance_x))
			off_x_bytes := i32_to_bytes(i32(glyph.bbx.x))
			off_y_bytes := i32_to_bytes(i32(-glyph.bbx.y))

			rx_bytes := f32_to_bytes(f32(glyph.rect_pos.x))
			ry_bytes := f32_to_bytes(f32(glyph.rect_pos.y))
			rw_bytes := f32_to_bytes(f32(glyph.bbx.width))
			rh_bytes := f32_to_bytes(f32(glyph.bbx.height))

			size :=
				size_of(off_x_bytes) +
				size_of(off_y_bytes) +
				size_of(advance_x_bytes) +
				size_of(rx_bytes) +
				size_of(ry_bytes) +
				size_of(rw_bytes) +
				size_of(rh_bytes)
			assert(size == size_of(ui.Glyph))

			os.write(file, advance_x_bytes[:])
			os.write(file, off_x_bytes[:])
			os.write(file, off_y_bytes[:])

			os.write(file, rx_bytes[:])
			os.write(file, ry_bytes[:])
			os.write(file, rw_bytes[:])
			os.write(file, rh_bytes[:])
		}

		os.flush(file)
		os.close(file)
	}

	{
		// Write font info and helper functions
		sheet_height := len(glyphs) * glyphs_height

		f := assets_file
		putline(f, "font_load_%s :: proc() -> ui.Font {{", name)
		putline(f, "\tpixels := #load(\"fonts/%s.rawimage.bin\")", name)
		putline(f, "\tglyphs := transmute([]ui.Glyph)#load(\"fonts/%s.glyphs.bin\")", name)
		putline(f, "")
		putline(
			f,
			"\ttexture := ui.load_texture(pixels, %d, %d, .UNCOMPRESSED_GRAY_ALPHA, 1)",
			glyphs_width,
			sheet_height,
		)
		putline(f, "")
		putline(f, "\treturn ui.Font {{")
		putline(f, "\t\tsize        = %d,", font_pixe_size)
		putline(f, "\t\tglyphs      = glyphs,")
		putline(f, "\t\tglyph_count = %d,", len(all_glyphs))
		putline(f, "\t\ttexture     = texture,")
		putline(f, "\t}}")
		putline(f, "}}")
	}

	return true
}

// Output rendered glyphs into the PBM image for debug purposes.
render_to_image :: proc(name: string, pixels: []byte, glyphs_width: int) {
	file, err := os.open(
		fmt.tprintf("build/%s.pbm", name),
		os.O_WRONLY | os.O_CREATE | os.O_TRUNC,
		0o644,
	)
	assert(err == nil)

	putline(file, "P1")
	putline(file, "%d %d", glyphs_width, len(pixels) / 2 / glyphs_width)
	for idx in 0 ..< len(pixels) / 2 {
		if pixels[idx * 2 + 1] == 0 {
			putline(file, "0")
		} else {
			putline(file, "1")
		}
	}

	os.flush(file)
	os.close(file)
}
