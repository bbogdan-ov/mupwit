package rlgl

import "core:c"
foreign import lib "../../../build/rlgl.a"

// RLGL (Raylib's abstractions over OpenGL) bindings for Odin.

Load_Extensions_Proc :: #type proc "c" (name: cstring) -> rawptr

LINES :: 0x0001
TRIANGLES :: 0x0004
QUADS :: 0x0007

Pixel_Format :: enum c.int {
	UNCOMPRESSED_GRAYSCALE = 1, // 8 bit per pixel (no alpha)
	UNCOMPRESSED_GRAY_ALPHA, // 8*2 bpp (2 channels)
	UNCOMPRESSED_R5G6B5, // 16 bpp
	UNCOMPRESSED_R8G8B8, // 24 bpp
	UNCOMPRESSED_R5G5B5A1, // 16 bpp (1 bit alpha)
	UNCOMPRESSED_R4G4B4A4, // 16 bpp (4 bit alpha)
	UNCOMPRESSED_R8G8B8A8, // 32 bpp
	UNCOMPRESSED_R32, // 32 bpp (1 channel - float)
	UNCOMPRESSED_R32G32B32, // 32*3 bpp (3 channels - float)
	UNCOMPRESSED_R32G32B32A32, // 32*4 bpp (4 channels - float)
	UNCOMPRESSED_R16, // 16 bpp (1 channel - half float)
	UNCOMPRESSED_R16G16B16, // 16*3 bpp (3 channels - half float)
	UNCOMPRESSED_R16G16B16A16, // 16*4 bpp (4 channels - half float)
	COMPRESSED_DXT1_RGB, // 4 bpp (no alpha)
	COMPRESSED_DXT1_RGBA, // 4 bpp (1 bit alpha)
	COMPRESSED_DXT3_RGBA, // 8 bpp
	COMPRESSED_DXT5_RGBA, // 8 bpp
	COMPRESSED_ETC1_RGB, // 4 bpp
	COMPRESSED_ETC2_RGB, // 4 bpp
	COMPRESSED_ETC2_EAC_RGBA, // 8 bpp
	COMPRESSED_PVRT_RGB, // 4 bpp
	COMPRESSED_PVRT_RGBA, // 4 bpp
	COMPRESSED_ASTC_4x4_RGBA, // 8 bpp
	COMPRESSED_ASTC_8x8_RGBA, // 2 bpp
}

@(default_calling_convention = "c", link_prefix = "rl")
foreign lib {
	@(link_name = "rlglInit")
	Init :: proc(width, height: c.int) ---
	@(link_name = "rlglClose")
	Close :: proc() ---
	LoadExtensions :: proc(loader: Load_Extensions_Proc) ---

	Viewport :: proc(x, y, width, height: c.int) ---

	Begin :: proc(mode: c.int) ---
	End :: proc() ---

	ClearColor :: proc(r, g, b, a: c.uchar) ---
	ClearScreenBuffers :: proc() ---
	Vertex2i :: proc(x, y: c.int) ---
	Vertex2f :: proc(x, y: c.float) ---
	Color4ub :: proc(r, g, b, a: c.uchar) ---
	SetTexture :: proc(id: c.uint) ---
	TexCoord2f :: proc(x, y: c.float) ---

	DrawRenderBatchActive :: proc() ---

	LoadTexture :: proc(pixels: [^]c.char, width, height: c.int, format: Pixel_Format, mipmapCount: c.int) -> c.uint ---
	UnloadTexture :: proc(id: c.uint) ---
}
