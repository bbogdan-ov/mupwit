//
// Generated using `odin-bindgen` and manually edited.
// https://github.com/karl-zylinski/odin-c-bindgen
//

/* cairo - a vector graphics library with display and print output
 *
 * Copyright © 2002 University of Southern California
 * Copyright © 2005 Red Hat, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it either under the terms of the GNU Lesser General Public
 * License version 2.1 as published by the Free Software Foundation
 * (the "LGPL") or, at your option, under the terms of the Mozilla
 * Public License Version 1.1 (the "MPL"). If you do not alter this
 * notice, a recipient may use your version of this file under either
 * the MPL or the LGPL.
 *
 * You should have received a copy of the LGPL along with this library
 * in the file COPYING-LGPL-2.1; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA 02110-1335, USA
 * You should have received a copy of the MPL along with this library
 * in the file COPYING-MPL-1.1
 *
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY
 * OF ANY KIND, either express or implied. See the LGPL or the MPL for
 * the specific language governing rights and limitations.
 *
 * The Original Code is the cairo graphics library.
 *
 * The Initial Developer of the Original Code is University of Southern
 * California.
 *
 * Contributor(s):
 *	Carl D. Worth <cworth@cworth.org>
 */
package cairo

@(require) foreign import lib "system:cairo"

import "core:c"

HAS_FC_FONT :: 1
HAS_FT_FONT :: 1
HAS_GOBJECT_FUNCTIONS :: 1
HAS_IMAGE_SURFACE :: 1
HAS_MIME_SURFACE :: 1
HAS_OBSERVER_SURFACE :: 1
HAS_PDF_SURFACE :: 1
HAS_PNG_FUNCTIONS :: 1
HAS_PS_SURFACE :: 1
HAS_RECORDING_SURFACE :: 1
HAS_SCRIPT_SURFACE :: 1
HAS_SVG_SURFACE :: 1
HAS_TEE_SURFACE :: 1
HAS_USER_FONT :: 1
HAS_XCB_SHM_FUNCTIONS :: 1
HAS_XCB_SURFACE :: 1
HAS_XLIB_SURFACE :: 1
HAS_XLIB_XRENDER_SURFACE :: 1

VERSION_MAJOR :: 1
VERSION_MINOR :: 18
VERSION_MICRO :: 4

VERSION :: (((VERSION_MAJOR) * 10000) + ((VERSION_MINOR) * 100) + ((VERSION_MICRO) * 1))

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	version :: proc() -> i32 ---
	version_string :: proc() -> cstring ---
}

/**
* cairo_bool_t:
*
* #cairo_bool_t is used for boolean values. Returns of type
* #cairo_bool_t will always be either 0 or 1, but testing against
* these values explicitly is not encouraged; just use the
* value as a boolean condition.
*
* <informalexample><programlisting>
*  if (cairo_in_stroke (cr, x, y)) {
*      /<!-- -->* do something *<!-- -->/
*  }
* </programlisting></informalexample>
*
* Since: 1.0
**/
bool_t :: i32
_cairo :: struct {}

/**
* cairo_t:
*
* A #cairo_t contains the current state of the rendering device,
* including coordinates of yet to be drawn shapes.
*
* Cairo contexts, as #cairo_t objects are named, are central to
* cairo and all drawing with cairo is always done to a #cairo_t
* object.
*
* Memory management of #cairo_t is done with
* cairo_reference() and cairo_destroy().
*
* Since: 1.0
**/
cairo_t :: _cairo
_cairo_surface :: struct {}

/**
* cairo_surface_t:
*
* A #cairo_surface_t represents an image, either as the destination
* of a drawing operation or as source when drawing onto another
* surface.  To draw to a #cairo_surface_t, create a cairo context
* with the surface as the target, using cairo_create().
*
* There are different subtypes of #cairo_surface_t for
* different drawing backends; for example, cairo_image_surface_create()
* creates a bitmap image in memory.
* The type of a surface can be queried with cairo_surface_get_type().
*
* The initial contents of a surface after creation depend upon the manner
* of its creation. If cairo creates the surface and backing storage for
* the user, it will be initially cleared; for example,
* cairo_image_surface_create() and cairo_surface_create_similar().
* Alternatively, if the user passes in a reference to some backing storage
* and asks cairo to wrap that in a #cairo_surface_t, then the contents are
* not modified; for example, cairo_image_surface_create_for_data() and
* cairo_xlib_surface_create().
*
* Memory management of #cairo_surface_t is done with
* cairo_surface_reference() and cairo_surface_destroy().
*
* Since: 1.0
**/
surface_t :: _cairo_surface
_cairo_device :: struct {}

/**
* cairo_device_t:
*
* A #cairo_device_t represents the driver interface for drawing
* operations to a #cairo_surface_t.  There are different subtypes of
* #cairo_device_t for different drawing backends.
*
* The type of a device can be queried with cairo_device_get_type().
*
* Memory management of #cairo_device_t is done with
* cairo_device_reference() and cairo_device_destroy().
*
* Since: 1.10
**/
device_t :: _cairo_device

/**
* cairo_matrix_t:
* @xx: xx component of the affine transformation
* @yx: yx component of the affine transformation
* @xy: xy component of the affine transformation
* @yy: yy component of the affine transformation
* @x0: X translation component of the affine transformation
* @y0: Y translation component of the affine transformation
*
* A #cairo_matrix_t holds an affine transformation, such as a scale,
* rotation, shear, or a combination of those. The transformation of
* a point (x, y) is given by:
* <programlisting>
*     x_new = xx * x + xy * y + x0;
*     y_new = yx * x + yy * y + y0;
* </programlisting>
*
* Since: 1.0
**/
_cairo_matrix :: struct {
	xx, yx: f64,
	xy, yy: f64,
	x0, y0: f64,
}

/**
* cairo_matrix_t:
* @xx: xx component of the affine transformation
* @yx: yx component of the affine transformation
* @xy: xy component of the affine transformation
* @yy: yy component of the affine transformation
* @x0: X translation component of the affine transformation
* @y0: Y translation component of the affine transformation
*
* A #cairo_matrix_t holds an affine transformation, such as a scale,
* rotation, shear, or a combination of those. The transformation of
* a point (x, y) is given by:
* <programlisting>
*     x_new = xx * x + xy * y + x0;
*     y_new = yx * x + yy * y + y0;
* </programlisting>
*
* Since: 1.0
**/
matrix_t :: _cairo_matrix
_cairo_pattern :: struct {}

/**
* cairo_pattern_t:
*
* A #cairo_pattern_t represents a source when drawing onto a
* surface. There are different subtypes of #cairo_pattern_t,
* for different types of sources; for example,
* cairo_pattern_create_rgb() creates a pattern for a solid
* opaque color.
*
* Other than various
* <function>cairo_pattern_create_<emphasis>type</emphasis>()</function>
* functions, some of the pattern types can be implicitly created using various
* <function>cairo_set_source_<emphasis>type</emphasis>()</function> functions;
* for example cairo_set_source_rgb().
*
* The type of a pattern can be queried with cairo_pattern_get_type().
*
* Memory management of #cairo_pattern_t is done with
* cairo_pattern_reference() and cairo_pattern_destroy().
*
* Since: 1.0
**/
pattern_t :: _cairo_pattern

/**
* cairo_destroy_func_t:
* @data: The data element being destroyed.
*
* #cairo_destroy_func_t the type of function which is called when a
* data element is destroyed. It is passed the pointer to the data
* element and should free any memory and resources allocated for it.
*
* Since: 1.0
**/
destroy_func_t :: proc "c" (data: rawptr)

/**
* cairo_user_data_key_t:
* @unused: not used; ignore.
*
* #cairo_user_data_key_t is used for attaching user data to cairo
* data structures.  The actual contents of the struct is never used,
* and there is no need to initialize the object; only the unique
* address of a #cairo_data_key_t object is used.  Typically, you
* would just use the address of a static #cairo_data_key_t object.
*
* Since: 1.0
**/
_cairo_user_data_key :: struct {
	unused: i32,
}

/**
* cairo_user_data_key_t:
* @unused: not used; ignore.
*
* #cairo_user_data_key_t is used for attaching user data to cairo
* data structures.  The actual contents of the struct is never used,
* and there is no need to initialize the object; only the unique
* address of a #cairo_data_key_t object is used.  Typically, you
* would just use the address of a static #cairo_data_key_t object.
*
* Since: 1.0
**/
user_data_key_t :: _cairo_user_data_key

/**
* cairo_status_t:
* @CAIRO_STATUS_SUCCESS: no error has occurred (Since 1.0)
* @CAIRO_STATUS_NO_MEMORY: out of memory (Since 1.0)
* @CAIRO_STATUS_INVALID_RESTORE: cairo_restore() called without matching cairo_save() (Since 1.0)
* @CAIRO_STATUS_INVALID_POP_GROUP: no saved group to pop, i.e. cairo_pop_group() without matching cairo_push_group() (Since 1.0)
* @CAIRO_STATUS_NO_CURRENT_POINT: no current point defined (Since 1.0)
* @CAIRO_STATUS_INVALID_MATRIX: invalid matrix (not invertible) (Since 1.0)
* @CAIRO_STATUS_INVALID_STATUS: invalid value for an input #cairo_status_t (Since 1.0)
* @CAIRO_STATUS_NULL_POINTER: %NULL pointer (Since 1.0)
* @CAIRO_STATUS_INVALID_STRING: input string not valid UTF-8 (Since 1.0)
* @CAIRO_STATUS_INVALID_PATH_DATA: input path data not valid (Since 1.0)
* @CAIRO_STATUS_READ_ERROR: error while reading from input stream (Since 1.0)
* @CAIRO_STATUS_WRITE_ERROR: error while writing to output stream (Since 1.0)
* @CAIRO_STATUS_SURFACE_FINISHED: target surface has been finished (Since 1.0)
* @CAIRO_STATUS_SURFACE_TYPE_MISMATCH: the surface type is not appropriate for the operation (Since 1.0)
* @CAIRO_STATUS_PATTERN_TYPE_MISMATCH: the pattern type is not appropriate for the operation (Since 1.0)
* @CAIRO_STATUS_INVALID_CONTENT: invalid value for an input #cairo_content_t (Since 1.0)
* @CAIRO_STATUS_INVALID_FORMAT: invalid value for an input #cairo_format_t (Since 1.0)
* @CAIRO_STATUS_INVALID_VISUAL: invalid value for an input Visual* (Since 1.0)
* @CAIRO_STATUS_FILE_NOT_FOUND: file not found (Since 1.0)
* @CAIRO_STATUS_INVALID_DASH: invalid value for a dash setting (Since 1.0)
* @CAIRO_STATUS_INVALID_DSC_COMMENT: invalid value for a DSC comment (Since 1.2)
* @CAIRO_STATUS_INVALID_INDEX: invalid index passed to getter (Since 1.4)
* @CAIRO_STATUS_CLIP_NOT_REPRESENTABLE: clip region not representable in desired format (Since 1.4)
* @CAIRO_STATUS_TEMP_FILE_ERROR: error creating or writing to a temporary file (Since 1.6)
* @CAIRO_STATUS_INVALID_STRIDE: invalid value for stride (Since 1.6)
* @CAIRO_STATUS_FONT_TYPE_MISMATCH: the font type is not appropriate for the operation (Since 1.8)
* @CAIRO_STATUS_USER_FONT_IMMUTABLE: the user-font is immutable (Since 1.8)
* @CAIRO_STATUS_USER_FONT_ERROR: error occurred in a user-font callback function (Since 1.8)
* @CAIRO_STATUS_NEGATIVE_COUNT: negative number used where it is not allowed (Since 1.8)
* @CAIRO_STATUS_INVALID_CLUSTERS: input clusters do not represent the accompanying text and glyph array (Since 1.8)
* @CAIRO_STATUS_INVALID_SLANT: invalid value for an input #cairo_font_slant_t (Since 1.8)
* @CAIRO_STATUS_INVALID_WEIGHT: invalid value for an input #cairo_font_weight_t (Since 1.8)
* @CAIRO_STATUS_INVALID_SIZE: invalid value (typically too big) for the size of the input (surface, pattern, etc.) (Since 1.10)
* @CAIRO_STATUS_USER_FONT_NOT_IMPLEMENTED: user-font method not implemented (Since 1.10)
* @CAIRO_STATUS_DEVICE_TYPE_MISMATCH: the device type is not appropriate for the operation (Since 1.10)
* @CAIRO_STATUS_DEVICE_ERROR: an operation to the device caused an unspecified error (Since 1.10)
* @CAIRO_STATUS_INVALID_MESH_CONSTRUCTION: a mesh pattern
*   construction operation was used outside of a
*   cairo_mesh_pattern_begin_patch()/cairo_mesh_pattern_end_patch()
*   pair (Since 1.12)
* @CAIRO_STATUS_DEVICE_FINISHED: target device has been finished (Since 1.12)
* @CAIRO_STATUS_JBIG2_GLOBAL_MISSING: %CAIRO_MIME_TYPE_JBIG2_GLOBAL_ID has been used on at least one image
*   but no image provided %CAIRO_MIME_TYPE_JBIG2_GLOBAL (Since 1.14)
* @CAIRO_STATUS_PNG_ERROR: error occurred in libpng while reading from or writing to a PNG file (Since 1.16)
* @CAIRO_STATUS_FREETYPE_ERROR: error occurred in libfreetype (Since 1.16)
* @CAIRO_STATUS_WIN32_GDI_ERROR: error occurred in the Windows Graphics Device Interface (Since 1.16)
* @CAIRO_STATUS_TAG_ERROR: invalid tag name, attributes, or nesting (Since 1.16)
* @CAIRO_STATUS_DWRITE_ERROR: error occurred in the Windows Direct Write API (Since 1.18)
* @CAIRO_STATUS_SVG_FONT_ERROR: error occurred in OpenType-SVG font rendering (Since 1.18)
* @CAIRO_STATUS_LAST_STATUS: this is a special value indicating the number of
*   status values defined in this enumeration.  When using this value, note
*   that the version of cairo at run-time may have additional status values
*   defined than the value of this symbol at compile-time. (Since 1.10)
*
* #cairo_status_t is used to indicate errors that can occur when
* using Cairo. In some cases it is returned directly by functions.
* but when using #cairo_t, the last error, if any, is stored in
* the context and can be retrieved with cairo_status().
*
* New entries may be added in future versions.  Use cairo_status_to_string()
* to get a human-readable representation of an error message.
*
* Since: 1.0
**/
_cairo_status :: enum u32 {
	SUCCESS                   = 0,
	NO_MEMORY                 = 1,
	INVALID_RESTORE           = 2,
	INVALID_POP_GROUP         = 3,
	NO_CURRENT_POINT          = 4,
	INVALID_MATRIX            = 5,
	INVALID_STATUS            = 6,
	NULL_POINTER              = 7,
	INVALID_STRING            = 8,
	INVALID_PATH_DATA         = 9,
	READ_ERROR                = 10,
	WRITE_ERROR               = 11,
	SURFACE_FINISHED          = 12,
	SURFACE_TYPE_MISMATCH     = 13,
	PATTERN_TYPE_MISMATCH     = 14,
	INVALID_CONTENT           = 15,
	INVALID_FORMAT            = 16,
	INVALID_VISUAL            = 17,
	FILE_NOT_FOUND            = 18,
	INVALID_DASH              = 19,
	INVALID_DSC_COMMENT       = 20,
	INVALID_INDEX             = 21,
	CLIP_NOT_REPRESENTABLE    = 22,
	TEMP_FILE_ERROR           = 23,
	INVALID_STRIDE            = 24,
	FONT_TYPE_MISMATCH        = 25,
	USER_FONT_IMMUTABLE       = 26,
	USER_FONT_ERROR           = 27,
	NEGATIVE_COUNT            = 28,
	INVALID_CLUSTERS          = 29,
	INVALID_SLANT             = 30,
	INVALID_WEIGHT            = 31,
	INVALID_SIZE              = 32,
	USER_FONT_NOT_IMPLEMENTED = 33,
	DEVICE_TYPE_MISMATCH      = 34,
	DEVICE_ERROR              = 35,
	INVALID_MESH_CONSTRUCTION = 36,
	DEVICE_FINISHED           = 37,
	JBIG2_GLOBAL_MISSING      = 38,
	PNG_ERROR                 = 39,
	FREETYPE_ERROR            = 40,
	WIN32_GDI_ERROR           = 41,
	TAG_ERROR                 = 42,
	DWRITE_ERROR              = 43,
	SVG_FONT_ERROR            = 44,
	LAST_STATUS               = 45,
}

/**
* cairo_status_t:
* @CAIRO_STATUS_SUCCESS: no error has occurred (Since 1.0)
* @CAIRO_STATUS_NO_MEMORY: out of memory (Since 1.0)
* @CAIRO_STATUS_INVALID_RESTORE: cairo_restore() called without matching cairo_save() (Since 1.0)
* @CAIRO_STATUS_INVALID_POP_GROUP: no saved group to pop, i.e. cairo_pop_group() without matching cairo_push_group() (Since 1.0)
* @CAIRO_STATUS_NO_CURRENT_POINT: no current point defined (Since 1.0)
* @CAIRO_STATUS_INVALID_MATRIX: invalid matrix (not invertible) (Since 1.0)
* @CAIRO_STATUS_INVALID_STATUS: invalid value for an input #cairo_status_t (Since 1.0)
* @CAIRO_STATUS_NULL_POINTER: %NULL pointer (Since 1.0)
* @CAIRO_STATUS_INVALID_STRING: input string not valid UTF-8 (Since 1.0)
* @CAIRO_STATUS_INVALID_PATH_DATA: input path data not valid (Since 1.0)
* @CAIRO_STATUS_READ_ERROR: error while reading from input stream (Since 1.0)
* @CAIRO_STATUS_WRITE_ERROR: error while writing to output stream (Since 1.0)
* @CAIRO_STATUS_SURFACE_FINISHED: target surface has been finished (Since 1.0)
* @CAIRO_STATUS_SURFACE_TYPE_MISMATCH: the surface type is not appropriate for the operation (Since 1.0)
* @CAIRO_STATUS_PATTERN_TYPE_MISMATCH: the pattern type is not appropriate for the operation (Since 1.0)
* @CAIRO_STATUS_INVALID_CONTENT: invalid value for an input #cairo_content_t (Since 1.0)
* @CAIRO_STATUS_INVALID_FORMAT: invalid value for an input #cairo_format_t (Since 1.0)
* @CAIRO_STATUS_INVALID_VISUAL: invalid value for an input Visual* (Since 1.0)
* @CAIRO_STATUS_FILE_NOT_FOUND: file not found (Since 1.0)
* @CAIRO_STATUS_INVALID_DASH: invalid value for a dash setting (Since 1.0)
* @CAIRO_STATUS_INVALID_DSC_COMMENT: invalid value for a DSC comment (Since 1.2)
* @CAIRO_STATUS_INVALID_INDEX: invalid index passed to getter (Since 1.4)
* @CAIRO_STATUS_CLIP_NOT_REPRESENTABLE: clip region not representable in desired format (Since 1.4)
* @CAIRO_STATUS_TEMP_FILE_ERROR: error creating or writing to a temporary file (Since 1.6)
* @CAIRO_STATUS_INVALID_STRIDE: invalid value for stride (Since 1.6)
* @CAIRO_STATUS_FONT_TYPE_MISMATCH: the font type is not appropriate for the operation (Since 1.8)
* @CAIRO_STATUS_USER_FONT_IMMUTABLE: the user-font is immutable (Since 1.8)
* @CAIRO_STATUS_USER_FONT_ERROR: error occurred in a user-font callback function (Since 1.8)
* @CAIRO_STATUS_NEGATIVE_COUNT: negative number used where it is not allowed (Since 1.8)
* @CAIRO_STATUS_INVALID_CLUSTERS: input clusters do not represent the accompanying text and glyph array (Since 1.8)
* @CAIRO_STATUS_INVALID_SLANT: invalid value for an input #cairo_font_slant_t (Since 1.8)
* @CAIRO_STATUS_INVALID_WEIGHT: invalid value for an input #cairo_font_weight_t (Since 1.8)
* @CAIRO_STATUS_INVALID_SIZE: invalid value (typically too big) for the size of the input (surface, pattern, etc.) (Since 1.10)
* @CAIRO_STATUS_USER_FONT_NOT_IMPLEMENTED: user-font method not implemented (Since 1.10)
* @CAIRO_STATUS_DEVICE_TYPE_MISMATCH: the device type is not appropriate for the operation (Since 1.10)
* @CAIRO_STATUS_DEVICE_ERROR: an operation to the device caused an unspecified error (Since 1.10)
* @CAIRO_STATUS_INVALID_MESH_CONSTRUCTION: a mesh pattern
*   construction operation was used outside of a
*   cairo_mesh_pattern_begin_patch()/cairo_mesh_pattern_end_patch()
*   pair (Since 1.12)
* @CAIRO_STATUS_DEVICE_FINISHED: target device has been finished (Since 1.12)
* @CAIRO_STATUS_JBIG2_GLOBAL_MISSING: %CAIRO_MIME_TYPE_JBIG2_GLOBAL_ID has been used on at least one image
*   but no image provided %CAIRO_MIME_TYPE_JBIG2_GLOBAL (Since 1.14)
* @CAIRO_STATUS_PNG_ERROR: error occurred in libpng while reading from or writing to a PNG file (Since 1.16)
* @CAIRO_STATUS_FREETYPE_ERROR: error occurred in libfreetype (Since 1.16)
* @CAIRO_STATUS_WIN32_GDI_ERROR: error occurred in the Windows Graphics Device Interface (Since 1.16)
* @CAIRO_STATUS_TAG_ERROR: invalid tag name, attributes, or nesting (Since 1.16)
* @CAIRO_STATUS_DWRITE_ERROR: error occurred in the Windows Direct Write API (Since 1.18)
* @CAIRO_STATUS_SVG_FONT_ERROR: error occurred in OpenType-SVG font rendering (Since 1.18)
* @CAIRO_STATUS_LAST_STATUS: this is a special value indicating the number of
*   status values defined in this enumeration.  When using this value, note
*   that the version of cairo at run-time may have additional status values
*   defined than the value of this symbol at compile-time. (Since 1.10)
*
* #cairo_status_t is used to indicate errors that can occur when
* using Cairo. In some cases it is returned directly by functions.
* but when using #cairo_t, the last error, if any, is stored in
* the context and can be retrieved with cairo_status().
*
* New entries may be added in future versions.  Use cairo_status_to_string()
* to get a human-readable representation of an error message.
*
* Since: 1.0
**/
status_t :: _cairo_status

/**
* cairo_content_t:
* @CAIRO_CONTENT_COLOR: The surface will hold color content only. (Since 1.0)
* @CAIRO_CONTENT_ALPHA: The surface will hold alpha content only. (Since 1.0)
* @CAIRO_CONTENT_COLOR_ALPHA: The surface will hold color and alpha content. (Since 1.0)
*
* #cairo_content_t is used to describe the content that a surface will
* contain, whether color information, alpha information (translucence
* vs. opacity), or both.
*
* Note: The large values here are designed to keep #cairo_content_t
* values distinct from #cairo_format_t values so that the
* implementation can detect the error if users confuse the two types.
*
* Since: 1.0
**/
_cairo_content :: enum u32 {
	COLOR       = 4096,
	ALPHA       = 8192,
	COLOR_ALPHA = 12288,
}

/**
* cairo_content_t:
* @CAIRO_CONTENT_COLOR: The surface will hold color content only. (Since 1.0)
* @CAIRO_CONTENT_ALPHA: The surface will hold alpha content only. (Since 1.0)
* @CAIRO_CONTENT_COLOR_ALPHA: The surface will hold color and alpha content. (Since 1.0)
*
* #cairo_content_t is used to describe the content that a surface will
* contain, whether color information, alpha information (translucence
* vs. opacity), or both.
*
* Note: The large values here are designed to keep #cairo_content_t
* values distinct from #cairo_format_t values so that the
* implementation can detect the error if users confuse the two types.
*
* Since: 1.0
**/
content_t :: _cairo_content

/**
* cairo_format_t:
* @CAIRO_FORMAT_INVALID: no such format exists or is supported.
* @CAIRO_FORMAT_ARGB32: each pixel is a 32-bit quantity, with
*   alpha in the upper 8 bits, then red, then green, then blue.
*   The 32-bit quantities are stored native-endian. Pre-multiplied
*   alpha is used. (That is, 50% transparent red is 0x80800000,
*   not 0x80ff0000.) (Since 1.0)
* @CAIRO_FORMAT_RGB24: each pixel is a 32-bit quantity, with
*   the upper 8 bits unused. Red, Green, and Blue are stored
*   in the remaining 24 bits in that order. (Since 1.0)
* @CAIRO_FORMAT_A8: each pixel is a 8-bit quantity holding
*   an alpha value. (Since 1.0)
* @CAIRO_FORMAT_A1: each pixel is a 1-bit quantity holding
*   an alpha value. Pixels are packed together into 32-bit
*   quantities. The ordering of the bits matches the
*   endianness of the platform. On a big-endian machine, the
*   first pixel is in the uppermost bit, on a little-endian
*   machine the first pixel is in the least-significant bit. (Since 1.0)
* @CAIRO_FORMAT_RGB16_565: each pixel is a 16-bit quantity
*   with red in the upper 5 bits, then green in the middle
*   6 bits, and blue in the lower 5 bits. (Since 1.2)
* @CAIRO_FORMAT_RGB30: like RGB24 but with 10bpc. (Since 1.12)
* @CAIRO_FORMAT_RGB96F: 3 floats, R, G, B. (Since 1.17.2)
* @CAIRO_FORMAT_RGBA128F: 4 floats, R, G, B, A. (Since 1.17.2)
*
* #cairo_format_t is used to identify the memory format of
* image data.
*
* New entries may be added in future versions.
*
* Since: 1.0
**/
_cairo_format :: enum i32 {
	INVALID   = -1,
	ARGB32    = 0,
	RGB24     = 1,
	A8        = 2,
	A1        = 3,
	RGB16_565 = 4,
	RGB30     = 5,
	RGB96F    = 6,
	RGBA128F  = 7,
}

/**
* cairo_format_t:
* @CAIRO_FORMAT_INVALID: no such format exists or is supported.
* @CAIRO_FORMAT_ARGB32: each pixel is a 32-bit quantity, with
*   alpha in the upper 8 bits, then red, then green, then blue.
*   The 32-bit quantities are stored native-endian. Pre-multiplied
*   alpha is used. (That is, 50% transparent red is 0x80800000,
*   not 0x80ff0000.) (Since 1.0)
* @CAIRO_FORMAT_RGB24: each pixel is a 32-bit quantity, with
*   the upper 8 bits unused. Red, Green, and Blue are stored
*   in the remaining 24 bits in that order. (Since 1.0)
* @CAIRO_FORMAT_A8: each pixel is a 8-bit quantity holding
*   an alpha value. (Since 1.0)
* @CAIRO_FORMAT_A1: each pixel is a 1-bit quantity holding
*   an alpha value. Pixels are packed together into 32-bit
*   quantities. The ordering of the bits matches the
*   endianness of the platform. On a big-endian machine, the
*   first pixel is in the uppermost bit, on a little-endian
*   machine the first pixel is in the least-significant bit. (Since 1.0)
* @CAIRO_FORMAT_RGB16_565: each pixel is a 16-bit quantity
*   with red in the upper 5 bits, then green in the middle
*   6 bits, and blue in the lower 5 bits. (Since 1.2)
* @CAIRO_FORMAT_RGB30: like RGB24 but with 10bpc. (Since 1.12)
* @CAIRO_FORMAT_RGB96F: 3 floats, R, G, B. (Since 1.17.2)
* @CAIRO_FORMAT_RGBA128F: 4 floats, R, G, B, A. (Since 1.17.2)
*
* #cairo_format_t is used to identify the memory format of
* image data.
*
* New entries may be added in future versions.
*
* Since: 1.0
**/
format_t :: _cairo_format

/**
* cairo_dither_t:
* @CAIRO_DITHER_NONE: No dithering.
* @CAIRO_DITHER_DEFAULT: Default choice at cairo compile time. Currently NONE.
* @CAIRO_DITHER_FAST: Fastest dithering algorithm supported by the backend
* @CAIRO_DITHER_GOOD: An algorithm with smoother dithering than FAST
* @CAIRO_DITHER_BEST: Best algorithm available in the backend
*
* Dither is an intentionally applied form of noise used to randomize
* quantization error, preventing large-scale patterns such as color banding
* in images (e.g. for gradients). Ordered dithering applies a precomputed
* threshold matrix to spread the errors smoothly.
*
*  #cairo_dither_t is modeled on pixman dithering algorithm choice.
* As of Pixman 0.40, FAST corresponds to a 8x8 ordered bayer noise and GOOD
* and BEST use an ordered 64x64 precomputed blue noise.
*
* Since: 1.18
**/
_cairo_dither :: enum u32 {
	NONE    = 0,
	DEFAULT = 1,
	FAST    = 2,
	GOOD    = 3,
	BEST    = 4,
}

/**
* cairo_dither_t:
* @CAIRO_DITHER_NONE: No dithering.
* @CAIRO_DITHER_DEFAULT: Default choice at cairo compile time. Currently NONE.
* @CAIRO_DITHER_FAST: Fastest dithering algorithm supported by the backend
* @CAIRO_DITHER_GOOD: An algorithm with smoother dithering than FAST
* @CAIRO_DITHER_BEST: Best algorithm available in the backend
*
* Dither is an intentionally applied form of noise used to randomize
* quantization error, preventing large-scale patterns such as color banding
* in images (e.g. for gradients). Ordered dithering applies a precomputed
* threshold matrix to spread the errors smoothly.
*
*  #cairo_dither_t is modeled on pixman dithering algorithm choice.
* As of Pixman 0.40, FAST corresponds to a 8x8 ordered bayer noise and GOOD
* and BEST use an ordered 64x64 precomputed blue noise.
*
* Since: 1.18
**/
dither_t :: _cairo_dither

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	pattern_set_dither :: proc(pattern: ^pattern_t, dither: dither_t) ---
	pattern_get_dither :: proc(pattern: ^pattern_t) -> dither_t ---
}

/**
* cairo_write_func_t:
* @closure: the output closure
* @data: the buffer containing the data to write
* @length: the amount of data to write
*
* #cairo_write_func_t is the type of function which is called when a
* backend needs to write data to an output stream.  It is passed the
* closure which was specified by the user at the time the write
* function was registered, the data to write and the length of the
* data in bytes.  The write function should return
* %CAIRO_STATUS_SUCCESS if all the data was successfully written,
* %CAIRO_STATUS_WRITE_ERROR otherwise.
*
* Returns: the status code of the write operation
*
* Since: 1.0
**/
write_func_t :: proc "c" (closure: rawptr, data: ^u8, length: u32) -> status_t

/**
* cairo_read_func_t:
* @closure: the input closure
* @data: the buffer into which to read the data
* @length: the amount of data to read
*
* #cairo_read_func_t is the type of function which is called when a
* backend needs to read data from an input stream.  It is passed the
* closure which was specified by the user at the time the read
* function was registered, the buffer to read the data into and the
* length of the data in bytes.  The read function should return
* %CAIRO_STATUS_SUCCESS if all the data was successfully read,
* %CAIRO_STATUS_READ_ERROR otherwise.
*
* Returns: the status code of the read operation
*
* Since: 1.0
**/
read_func_t :: proc "c" (closure: rawptr, data: ^u8, length: u32) -> status_t

/**
* cairo_rectangle_int_t:
* @x: X coordinate of the left side of the rectangle
* @y: Y coordinate of the top side of the rectangle
* @width: width of the rectangle
* @height: height of the rectangle
*
* A data structure for holding a rectangle with integer coordinates.
*
* Since: 1.10
**/
_cairo_rectangle_int :: struct {
	x, y:          i32,
	width, height: i32,
}

/**
* cairo_rectangle_int_t:
* @x: X coordinate of the left side of the rectangle
* @y: Y coordinate of the top side of the rectangle
* @width: width of the rectangle
* @height: height of the rectangle
*
* A data structure for holding a rectangle with integer coordinates.
*
* Since: 1.10
**/
rectangle_int_t :: _cairo_rectangle_int

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	/* Functions for manipulating state objects */
	create :: proc(target: ^surface_t) -> ^cairo_t ---
	reference :: proc(cr: ^cairo_t) -> ^cairo_t ---
	destroy :: proc(cr: ^cairo_t) ---
	get_reference_count :: proc(cr: ^cairo_t) -> u32 ---
	get_user_data :: proc(cr: ^cairo_t, key: ^user_data_key_t) -> rawptr ---
	set_user_data :: proc(cr: ^cairo_t, key: ^user_data_key_t, user_data: rawptr, destroy: destroy_func_t) -> status_t ---
	save :: proc(cr: ^cairo_t) ---
	restore :: proc(cr: ^cairo_t) ---
	push_group :: proc(cr: ^cairo_t) ---
	push_group_with_content :: proc(cr: ^cairo_t, content: content_t) ---
	pop_group :: proc(cr: ^cairo_t) -> ^pattern_t ---
	pop_group_to_source :: proc(cr: ^cairo_t) ---
}

/**
* cairo_operator_t:
* @CAIRO_OPERATOR_CLEAR: clear destination layer (bounded) (Since 1.0)
* @CAIRO_OPERATOR_SOURCE: replace destination layer (bounded) (Since 1.0)
* @CAIRO_OPERATOR_OVER: draw source layer on top of destination layer
* (bounded) (Since 1.0)
* @CAIRO_OPERATOR_IN: draw source where there was destination content
* (unbounded) (Since 1.0)
* @CAIRO_OPERATOR_OUT: draw source where there was no destination
* content (unbounded) (Since 1.0)
* @CAIRO_OPERATOR_ATOP: draw source on top of destination content and
* only there (Since 1.0)
* @CAIRO_OPERATOR_DEST: ignore the source (Since 1.0)
* @CAIRO_OPERATOR_DEST_OVER: draw destination on top of source (Since 1.0)
* @CAIRO_OPERATOR_DEST_IN: leave destination only where there was
* source content (unbounded) (Since 1.0)
* @CAIRO_OPERATOR_DEST_OUT: leave destination only where there was no
* source content (Since 1.0)
* @CAIRO_OPERATOR_DEST_ATOP: leave destination on top of source content
* and only there (unbounded) (Since 1.0)
* @CAIRO_OPERATOR_XOR: source and destination are shown where there is only
* one of them (Since 1.0)
* @CAIRO_OPERATOR_ADD: source and destination layers are accumulated (Since 1.0)
* @CAIRO_OPERATOR_SATURATE: like over, but assuming source and dest are
* disjoint geometries (Since 1.0)
* @CAIRO_OPERATOR_MULTIPLY: source and destination layers are multiplied.
* This causes the result to be at least as dark as the darker inputs. (Since 1.10)
* @CAIRO_OPERATOR_SCREEN: source and destination are complemented and
* multiplied. This causes the result to be at least as light as the lighter
* inputs. (Since 1.10)
* @CAIRO_OPERATOR_OVERLAY: multiplies or screens, depending on the
* lightness of the destination color. (Since 1.10)
* @CAIRO_OPERATOR_DARKEN: replaces the destination with the source if it
* is darker, otherwise keeps the source. (Since 1.10)
* @CAIRO_OPERATOR_LIGHTEN: replaces the destination with the source if it
* is lighter, otherwise keeps the source. (Since 1.10)
* @CAIRO_OPERATOR_COLOR_DODGE: brightens the destination color to reflect
* the source color. (Since 1.10)
* @CAIRO_OPERATOR_COLOR_BURN: darkens the destination color to reflect
* the source color. (Since 1.10)
* @CAIRO_OPERATOR_HARD_LIGHT: Multiplies or screens, dependent on source
* color. (Since 1.10)
* @CAIRO_OPERATOR_SOFT_LIGHT: Darkens or lightens, dependent on source
* color. (Since 1.10)
* @CAIRO_OPERATOR_DIFFERENCE: Takes the difference of the source and
* destination color. (Since 1.10)
* @CAIRO_OPERATOR_EXCLUSION: Produces an effect similar to difference, but
* with lower contrast. (Since 1.10)
* @CAIRO_OPERATOR_HSL_HUE: Creates a color with the hue of the source
* and the saturation and luminosity of the target. (Since 1.10)
* @CAIRO_OPERATOR_HSL_SATURATION: Creates a color with the saturation
* of the source and the hue and luminosity of the target. Painting with
* this mode onto a gray area produces no change. (Since 1.10)
* @CAIRO_OPERATOR_HSL_COLOR: Creates a color with the hue and saturation
* of the source and the luminosity of the target. This preserves the gray
* levels of the target and is useful for coloring monochrome images or
* tinting color images. (Since 1.10)
* @CAIRO_OPERATOR_HSL_LUMINOSITY: Creates a color with the luminosity of
* the source and the hue and saturation of the target. This produces an
* inverse effect to @CAIRO_OPERATOR_HSL_COLOR. (Since 1.10)
*
* #cairo_operator_t is used to set the compositing operator for all cairo
* drawing operations.
*
* The default operator is %CAIRO_OPERATOR_OVER.
*
* The operators marked as <firstterm>unbounded</firstterm> modify their
* destination even outside of the mask layer (that is, their effect is not
* bound by the mask layer).  However, their effect can still be limited by
* way of clipping.
*
* To keep things simple, the operator descriptions here
* document the behavior for when both source and destination are either fully
* transparent or fully opaque.  The actual implementation works for
* translucent layers too.
* For a more detailed explanation of the effects of each operator, including
* the mathematical definitions, see
* <ulink url="https://cairographics.org/operators/">https://cairographics.org/operators/</ulink>.
*
* Since: 1.0
**/
_cairo_operator :: enum u32 {
	CLEAR          = 0,
	SOURCE         = 1,
	OVER           = 2,
	IN             = 3,
	OUT            = 4,
	ATOP           = 5,
	DEST           = 6,
	DEST_OVER      = 7,
	DEST_IN        = 8,
	DEST_OUT       = 9,
	DEST_ATOP      = 10,
	XOR            = 11,
	ADD            = 12,
	SATURATE       = 13,
	MULTIPLY       = 14,
	SCREEN         = 15,
	OVERLAY        = 16,
	DARKEN         = 17,
	LIGHTEN        = 18,
	COLOR_DODGE    = 19,
	COLOR_BURN     = 20,
	HARD_LIGHT     = 21,
	SOFT_LIGHT     = 22,
	DIFFERENCE     = 23,
	EXCLUSION      = 24,
	HSL_HUE        = 25,
	HSL_SATURATION = 26,
	HSL_COLOR      = 27,
	HSL_LUMINOSITY = 28,
}

/**
* cairo_operator_t:
* @CAIRO_OPERATOR_CLEAR: clear destination layer (bounded) (Since 1.0)
* @CAIRO_OPERATOR_SOURCE: replace destination layer (bounded) (Since 1.0)
* @CAIRO_OPERATOR_OVER: draw source layer on top of destination layer
* (bounded) (Since 1.0)
* @CAIRO_OPERATOR_IN: draw source where there was destination content
* (unbounded) (Since 1.0)
* @CAIRO_OPERATOR_OUT: draw source where there was no destination
* content (unbounded) (Since 1.0)
* @CAIRO_OPERATOR_ATOP: draw source on top of destination content and
* only there (Since 1.0)
* @CAIRO_OPERATOR_DEST: ignore the source (Since 1.0)
* @CAIRO_OPERATOR_DEST_OVER: draw destination on top of source (Since 1.0)
* @CAIRO_OPERATOR_DEST_IN: leave destination only where there was
* source content (unbounded) (Since 1.0)
* @CAIRO_OPERATOR_DEST_OUT: leave destination only where there was no
* source content (Since 1.0)
* @CAIRO_OPERATOR_DEST_ATOP: leave destination on top of source content
* and only there (unbounded) (Since 1.0)
* @CAIRO_OPERATOR_XOR: source and destination are shown where there is only
* one of them (Since 1.0)
* @CAIRO_OPERATOR_ADD: source and destination layers are accumulated (Since 1.0)
* @CAIRO_OPERATOR_SATURATE: like over, but assuming source and dest are
* disjoint geometries (Since 1.0)
* @CAIRO_OPERATOR_MULTIPLY: source and destination layers are multiplied.
* This causes the result to be at least as dark as the darker inputs. (Since 1.10)
* @CAIRO_OPERATOR_SCREEN: source and destination are complemented and
* multiplied. This causes the result to be at least as light as the lighter
* inputs. (Since 1.10)
* @CAIRO_OPERATOR_OVERLAY: multiplies or screens, depending on the
* lightness of the destination color. (Since 1.10)
* @CAIRO_OPERATOR_DARKEN: replaces the destination with the source if it
* is darker, otherwise keeps the source. (Since 1.10)
* @CAIRO_OPERATOR_LIGHTEN: replaces the destination with the source if it
* is lighter, otherwise keeps the source. (Since 1.10)
* @CAIRO_OPERATOR_COLOR_DODGE: brightens the destination color to reflect
* the source color. (Since 1.10)
* @CAIRO_OPERATOR_COLOR_BURN: darkens the destination color to reflect
* the source color. (Since 1.10)
* @CAIRO_OPERATOR_HARD_LIGHT: Multiplies or screens, dependent on source
* color. (Since 1.10)
* @CAIRO_OPERATOR_SOFT_LIGHT: Darkens or lightens, dependent on source
* color. (Since 1.10)
* @CAIRO_OPERATOR_DIFFERENCE: Takes the difference of the source and
* destination color. (Since 1.10)
* @CAIRO_OPERATOR_EXCLUSION: Produces an effect similar to difference, but
* with lower contrast. (Since 1.10)
* @CAIRO_OPERATOR_HSL_HUE: Creates a color with the hue of the source
* and the saturation and luminosity of the target. (Since 1.10)
* @CAIRO_OPERATOR_HSL_SATURATION: Creates a color with the saturation
* of the source and the hue and luminosity of the target. Painting with
* this mode onto a gray area produces no change. (Since 1.10)
* @CAIRO_OPERATOR_HSL_COLOR: Creates a color with the hue and saturation
* of the source and the luminosity of the target. This preserves the gray
* levels of the target and is useful for coloring monochrome images or
* tinting color images. (Since 1.10)
* @CAIRO_OPERATOR_HSL_LUMINOSITY: Creates a color with the luminosity of
* the source and the hue and saturation of the target. This produces an
* inverse effect to @CAIRO_OPERATOR_HSL_COLOR. (Since 1.10)
*
* #cairo_operator_t is used to set the compositing operator for all cairo
* drawing operations.
*
* The default operator is %CAIRO_OPERATOR_OVER.
*
* The operators marked as <firstterm>unbounded</firstterm> modify their
* destination even outside of the mask layer (that is, their effect is not
* bound by the mask layer).  However, their effect can still be limited by
* way of clipping.
*
* To keep things simple, the operator descriptions here
* document the behavior for when both source and destination are either fully
* transparent or fully opaque.  The actual implementation works for
* translucent layers too.
* For a more detailed explanation of the effects of each operator, including
* the mathematical definitions, see
* <ulink url="https://cairographics.org/operators/">https://cairographics.org/operators/</ulink>.
*
* Since: 1.0
**/
operator_t :: _cairo_operator

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	set_operator :: proc(cr: ^cairo_t, op: operator_t) ---
	set_source :: proc(cr: ^cairo_t, source: ^pattern_t) ---
	set_source_rgb :: proc(cr: ^cairo_t, red: f64, green: f64, blue: f64) ---
	set_source_rgba :: proc(cr: ^cairo_t, red: f64, green: f64, blue: f64, alpha: f64) ---
	set_source_surface :: proc(cr: ^cairo_t, surface: ^surface_t, x: f64, y: f64) ---
	set_tolerance :: proc(cr: ^cairo_t, tolerance: f64) ---
}

/**
* cairo_antialias_t:
* @CAIRO_ANTIALIAS_DEFAULT: Use the default antialiasing for
*   the subsystem and target device, since 1.0
* @CAIRO_ANTIALIAS_NONE: Use a bilevel alpha mask, since 1.0
* @CAIRO_ANTIALIAS_GRAY: Perform single-color antialiasing (using
*  shades of gray for black text on a white background, for example), since 1.0
* @CAIRO_ANTIALIAS_SUBPIXEL: Perform antialiasing by taking
*  advantage of the order of subpixel elements on devices
*  such as LCD panels, since 1.0
* @CAIRO_ANTIALIAS_FAST: Hint that the backend should perform some
* antialiasing but prefer speed over quality, since 1.12
* @CAIRO_ANTIALIAS_GOOD: The backend should balance quality against
* performance, since 1.12
* @CAIRO_ANTIALIAS_BEST: Hint that the backend should render at the highest
* quality, sacrificing speed if necessary, since 1.12
*
* Specifies the type of antialiasing to do when rendering text or shapes.
*
* As it is not necessarily clear from the above what advantages a particular
* antialias method provides, since 1.12, there is also a set of hints:
* @CAIRO_ANTIALIAS_FAST: Allow the backend to degrade raster quality for speed
* @CAIRO_ANTIALIAS_GOOD: A balance between speed and quality
* @CAIRO_ANTIALIAS_BEST: A high-fidelity, but potentially slow, raster mode
*
* These make no guarantee on how the backend will perform its rasterisation
* (if it even rasterises!), nor that they have any differing effect other
* than to enable some form of antialiasing. In the case of glyph rendering,
* @CAIRO_ANTIALIAS_FAST and @CAIRO_ANTIALIAS_GOOD will be mapped to
* @CAIRO_ANTIALIAS_GRAY, with @CAIRO_ANTALIAS_BEST being equivalent to
* @CAIRO_ANTIALIAS_SUBPIXEL.
*
* The interpretation of @CAIRO_ANTIALIAS_DEFAULT is left entirely up to
* the backend, typically this will be similar to @CAIRO_ANTIALIAS_GOOD.
*
* Since: 1.0
**/
_cairo_antialias :: enum u32 {
	DEFAULT  = 0,

	/* method */
	NONE     = 1,
	GRAY     = 2,
	SUBPIXEL = 3,

	/* hints */
	FAST     = 4,
	GOOD     = 5,
	BEST     = 6,
}

/**
* cairo_antialias_t:
* @CAIRO_ANTIALIAS_DEFAULT: Use the default antialiasing for
*   the subsystem and target device, since 1.0
* @CAIRO_ANTIALIAS_NONE: Use a bilevel alpha mask, since 1.0
* @CAIRO_ANTIALIAS_GRAY: Perform single-color antialiasing (using
*  shades of gray for black text on a white background, for example), since 1.0
* @CAIRO_ANTIALIAS_SUBPIXEL: Perform antialiasing by taking
*  advantage of the order of subpixel elements on devices
*  such as LCD panels, since 1.0
* @CAIRO_ANTIALIAS_FAST: Hint that the backend should perform some
* antialiasing but prefer speed over quality, since 1.12
* @CAIRO_ANTIALIAS_GOOD: The backend should balance quality against
* performance, since 1.12
* @CAIRO_ANTIALIAS_BEST: Hint that the backend should render at the highest
* quality, sacrificing speed if necessary, since 1.12
*
* Specifies the type of antialiasing to do when rendering text or shapes.
*
* As it is not necessarily clear from the above what advantages a particular
* antialias method provides, since 1.12, there is also a set of hints:
* @CAIRO_ANTIALIAS_FAST: Allow the backend to degrade raster quality for speed
* @CAIRO_ANTIALIAS_GOOD: A balance between speed and quality
* @CAIRO_ANTIALIAS_BEST: A high-fidelity, but potentially slow, raster mode
*
* These make no guarantee on how the backend will perform its rasterisation
* (if it even rasterises!), nor that they have any differing effect other
* than to enable some form of antialiasing. In the case of glyph rendering,
* @CAIRO_ANTIALIAS_FAST and @CAIRO_ANTIALIAS_GOOD will be mapped to
* @CAIRO_ANTIALIAS_GRAY, with @CAIRO_ANTALIAS_BEST being equivalent to
* @CAIRO_ANTIALIAS_SUBPIXEL.
*
* The interpretation of @CAIRO_ANTIALIAS_DEFAULT is left entirely up to
* the backend, typically this will be similar to @CAIRO_ANTIALIAS_GOOD.
*
* Since: 1.0
**/
antialias_t :: _cairo_antialias

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	set_antialias :: proc(cr: ^cairo_t, antialias: antialias_t) ---
}

/**
* cairo_fill_rule_t:
* @CAIRO_FILL_RULE_WINDING: If the path crosses the ray from
* left-to-right, counts +1. If the path crosses the ray
* from right to left, counts -1. (Left and right are determined
* from the perspective of looking along the ray from the starting
* point.) If the total count is non-zero, the point will be filled. (Since 1.0)
* @CAIRO_FILL_RULE_EVEN_ODD: Counts the total number of
* intersections, without regard to the orientation of the contour. If
* the total number of intersections is odd, the point will be
* filled. (Since 1.0)
*
* #cairo_fill_rule_t is used to select how paths are filled. For both
* fill rules, whether or not a point is included in the fill is
* determined by taking a ray from that point to infinity and looking
* at intersections with the path. The ray can be in any direction,
* as long as it doesn't pass through the end point of a segment
* or have a tricky intersection such as intersecting tangent to the path.
* (Note that filling is not actually implemented in this way. This
* is just a description of the rule that is applied.)
*
* The default fill rule is %CAIRO_FILL_RULE_WINDING.
*
* New entries may be added in future versions.
*
* Since: 1.0
**/
_cairo_fill_rule :: enum u32 {
	WINDING  = 0,
	EVEN_ODD = 1,
}

/**
* cairo_fill_rule_t:
* @CAIRO_FILL_RULE_WINDING: If the path crosses the ray from
* left-to-right, counts +1. If the path crosses the ray
* from right to left, counts -1. (Left and right are determined
* from the perspective of looking along the ray from the starting
* point.) If the total count is non-zero, the point will be filled. (Since 1.0)
* @CAIRO_FILL_RULE_EVEN_ODD: Counts the total number of
* intersections, without regard to the orientation of the contour. If
* the total number of intersections is odd, the point will be
* filled. (Since 1.0)
*
* #cairo_fill_rule_t is used to select how paths are filled. For both
* fill rules, whether or not a point is included in the fill is
* determined by taking a ray from that point to infinity and looking
* at intersections with the path. The ray can be in any direction,
* as long as it doesn't pass through the end point of a segment
* or have a tricky intersection such as intersecting tangent to the path.
* (Note that filling is not actually implemented in this way. This
* is just a description of the rule that is applied.)
*
* The default fill rule is %CAIRO_FILL_RULE_WINDING.
*
* New entries may be added in future versions.
*
* Since: 1.0
**/
fill_rule_t :: _cairo_fill_rule

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	set_fill_rule :: proc(cr: ^cairo_t, fill_rule: fill_rule_t) ---
	set_line_width :: proc(cr: ^cairo_t, width: f64) ---
	set_hairline :: proc(cr: ^cairo_t, set_hairline: bool_t) ---
}

/**
* cairo_line_cap_t:
* @CAIRO_LINE_CAP_BUTT: start(stop) the line exactly at the start(end) point (Since 1.0)
* @CAIRO_LINE_CAP_ROUND: use a round ending, the center of the circle is the end point (Since 1.0)
* @CAIRO_LINE_CAP_SQUARE: use squared ending, the center of the square is the end point (Since 1.0)
*
* Specifies how to render the endpoints of the path when stroking.
*
* The default line cap style is %CAIRO_LINE_CAP_BUTT.
*
* Since: 1.0
**/
_cairo_line_cap :: enum u32 {
	BUTT   = 0,
	ROUND  = 1,
	SQUARE = 2,
}

/**
* cairo_line_cap_t:
* @CAIRO_LINE_CAP_BUTT: start(stop) the line exactly at the start(end) point (Since 1.0)
* @CAIRO_LINE_CAP_ROUND: use a round ending, the center of the circle is the end point (Since 1.0)
* @CAIRO_LINE_CAP_SQUARE: use squared ending, the center of the square is the end point (Since 1.0)
*
* Specifies how to render the endpoints of the path when stroking.
*
* The default line cap style is %CAIRO_LINE_CAP_BUTT.
*
* Since: 1.0
**/
line_cap_t :: _cairo_line_cap

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	set_line_cap :: proc(cr: ^cairo_t, line_cap: line_cap_t) ---
}

/**
* cairo_line_join_t:
* @CAIRO_LINE_JOIN_MITER: use a sharp (angled) corner, see
* cairo_set_miter_limit() (Since 1.0)
* @CAIRO_LINE_JOIN_ROUND: use a rounded join, the center of the circle is the
* joint point (Since 1.0)
* @CAIRO_LINE_JOIN_BEVEL: use a cut-off join, the join is cut off at half
* the line width from the joint point (Since 1.0)
*
* Specifies how to render the junction of two lines when stroking.
*
* The default line join style is %CAIRO_LINE_JOIN_MITER.
*
* Since: 1.0
**/
_cairo_line_join :: enum u32 {
	MITER = 0,
	ROUND = 1,
	BEVEL = 2,
}

/**
* cairo_line_join_t:
* @CAIRO_LINE_JOIN_MITER: use a sharp (angled) corner, see
* cairo_set_miter_limit() (Since 1.0)
* @CAIRO_LINE_JOIN_ROUND: use a rounded join, the center of the circle is the
* joint point (Since 1.0)
* @CAIRO_LINE_JOIN_BEVEL: use a cut-off join, the join is cut off at half
* the line width from the joint point (Since 1.0)
*
* Specifies how to render the junction of two lines when stroking.
*
* The default line join style is %CAIRO_LINE_JOIN_MITER.
*
* Since: 1.0
**/
line_join_t :: _cairo_line_join

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	set_line_join :: proc(cr: ^cairo_t, line_join: line_join_t) ---
	set_dash :: proc(cr: ^cairo_t, dashes: ^f64, num_dashes: i32, offset: f64) ---
	set_miter_limit :: proc(cr: ^cairo_t, limit: f64) ---
	translate :: proc(cr: ^cairo_t, tx: f64, ty: f64) ---
	scale :: proc(cr: ^cairo_t, sx: f64, sy: f64) ---
	rotate :: proc(cr: ^cairo_t, angle: f64) ---
	transform :: proc(cr: ^cairo_t, _matrix: ^matrix_t) ---
	set_matrix :: proc(cr: ^cairo_t, _matrix: ^matrix_t) ---
	identity_matrix :: proc(cr: ^cairo_t) ---
	user_to_device :: proc(cr: ^cairo_t, x: ^f64, y: ^f64) ---
	user_to_device_distance :: proc(cr: ^cairo_t, dx: ^f64, dy: ^f64) ---
	device_to_user :: proc(cr: ^cairo_t, x: ^f64, y: ^f64) ---
	device_to_user_distance :: proc(cr: ^cairo_t, dx: ^f64, dy: ^f64) ---

	/* Path creation functions */
	new_path :: proc(cr: ^cairo_t) ---
	move_to :: proc(cr: ^cairo_t, x: f64, y: f64) ---
	new_sub_path :: proc(cr: ^cairo_t) ---
	line_to :: proc(cr: ^cairo_t, x: f64, y: f64) ---
	curve_to :: proc(cr: ^cairo_t, x1: f64, y1: f64, x2: f64, y2: f64, x3: f64, y3: f64) ---
	arc :: proc(cr: ^cairo_t, xc: f64, yc: f64, radius: f64, angle1: f64, angle2: f64) ---
	arc_negative :: proc(cr: ^cairo_t, xc: f64, yc: f64, radius: f64, angle1: f64, angle2: f64) ---

	/* XXX: NYI
	cairo_public void
	cairo_arc_to (cairo_t *cr,
	double x1, double y1,
	double x2, double y2,
	double radius);
	*/
	rel_move_to :: proc(cr: ^cairo_t, dx: f64, dy: f64) ---
	rel_line_to :: proc(cr: ^cairo_t, dx: f64, dy: f64) ---
	rel_curve_to :: proc(cr: ^cairo_t, dx1: f64, dy1: f64, dx2: f64, dy2: f64, dx3: f64, dy3: f64) ---
	rectangle :: proc(cr: ^cairo_t, x: f64, y: f64, width: f64, height: f64) ---

	/* XXX: NYI
	cairo_public void
	cairo_stroke_to_path (cairo_t *cr);
	*/
	close_path :: proc(cr: ^cairo_t) ---
	path_extents :: proc(cr: ^cairo_t, x1: ^f64, y1: ^f64, x2: ^f64, y2: ^f64) ---

	/* Painting functions */
	paint :: proc(cr: ^cairo_t) ---
	paint_with_alpha :: proc(cr: ^cairo_t, alpha: f64) ---
	mask :: proc(cr: ^cairo_t, pattern: ^pattern_t) ---
	mask_surface :: proc(cr: ^cairo_t, surface: ^surface_t, surface_x: f64, surface_y: f64) ---
	stroke :: proc(cr: ^cairo_t) ---
	stroke_preserve :: proc(cr: ^cairo_t) ---
	fill :: proc(cr: ^cairo_t) ---
	fill_preserve :: proc(cr: ^cairo_t) ---
	copy_page :: proc(cr: ^cairo_t) ---
	show_page :: proc(cr: ^cairo_t) ---

	/* Insideness testing */
	in_stroke :: proc(cr: ^cairo_t, x: f64, y: f64) -> bool_t ---
	in_fill :: proc(cr: ^cairo_t, x: f64, y: f64) -> bool_t ---
	in_clip :: proc(cr: ^cairo_t, x: f64, y: f64) -> bool_t ---

	/* Rectangular extents */
	stroke_extents :: proc(cr: ^cairo_t, x1: ^f64, y1: ^f64, x2: ^f64, y2: ^f64) ---
	fill_extents :: proc(cr: ^cairo_t, x1: ^f64, y1: ^f64, x2: ^f64, y2: ^f64) ---

	/* Clipping */
	reset_clip :: proc(cr: ^cairo_t) ---
	clip :: proc(cr: ^cairo_t) ---
	clip_preserve :: proc(cr: ^cairo_t) ---
	clip_extents :: proc(cr: ^cairo_t, x1: ^f64, y1: ^f64, x2: ^f64, y2: ^f64) ---
}

/**
* cairo_rectangle_t:
* @x: X coordinate of the left side of the rectangle
* @y: Y coordinate of the top side of the rectangle
* @width: width of the rectangle
* @height: height of the rectangle
*
* A data structure for holding a rectangle.
*
* Since: 1.4
**/
_cairo_rectangle :: struct {
	x, y, width, height: f64,
}

/**
* cairo_rectangle_t:
* @x: X coordinate of the left side of the rectangle
* @y: Y coordinate of the top side of the rectangle
* @width: width of the rectangle
* @height: height of the rectangle
*
* A data structure for holding a rectangle.
*
* Since: 1.4
**/
rectangle_t :: _cairo_rectangle

/**
* cairo_rectangle_list_t:
* @status: Error status of the rectangle list
* @rectangles: Array containing the rectangles
* @num_rectangles: Number of rectangles in this list
*
* A data structure for holding a dynamically allocated
* array of rectangles.
*
* Since: 1.4
**/
_cairo_rectangle_list :: struct {
	status:         status_t,
	rectangles:     ^rectangle_t,
	num_rectangles: i32,
}

/**
* cairo_rectangle_list_t:
* @status: Error status of the rectangle list
* @rectangles: Array containing the rectangles
* @num_rectangles: Number of rectangles in this list
*
* A data structure for holding a dynamically allocated
* array of rectangles.
*
* Since: 1.4
**/
rectangle_list_t :: _cairo_rectangle_list

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	copy_clip_rectangle_list :: proc(cr: ^cairo_t) -> ^rectangle_list_t ---
	rectangle_list_destroy :: proc(rectangle_list: ^rectangle_list_t) ---
}

/* Logical structure tagging functions */
TAG_DEST :: "cairo.dest"
TAG_LINK :: "Link"
TAG_CONTENT :: "cairo.content"
TAG_CONTENT_REF :: "cairo.content_ref"

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	tag_begin :: proc(cr: ^cairo_t, tag_name: cstring, attributes: cstring) ---
	tag_end :: proc(cr: ^cairo_t, tag_name: cstring) ---
}

/**
* cairo_scaled_font_t:
*
* A #cairo_scaled_font_t is a font scaled to a particular size and device
* resolution. A #cairo_scaled_font_t is most useful for low-level font
* usage where a library or application wants to cache a reference
* to a scaled font to speed up the computation of metrics.
*
* There are various types of scaled fonts, depending on the
* <firstterm>font backend</firstterm> they use. The type of a
* scaled font can be queried using cairo_scaled_font_get_type().
*
* Memory management of #cairo_scaled_font_t is done with
* cairo_scaled_font_reference() and cairo_scaled_font_destroy().
*
* Since: 1.0
**/
scaled_font_t :: _cairo_scaled_font
_cairo_scaled_font :: struct {}
_cairo_font_face :: struct {}

/**
* cairo_font_face_t:
*
* A #cairo_font_face_t specifies all aspects of a font other
* than the size or font matrix (a font matrix is used to distort
* a font by shearing it or scaling it unequally in the two
* directions) . A font face can be set on a #cairo_t by using
* cairo_set_font_face(); the size and font matrix are set with
* cairo_set_font_size() and cairo_set_font_matrix().
*
* There are various types of font faces, depending on the
* <firstterm>font backend</firstterm> they use. The type of a
* font face can be queried using cairo_font_face_get_type().
*
* Memory management of #cairo_font_face_t is done with
* cairo_font_face_reference() and cairo_font_face_destroy().
*
* Since: 1.0
**/
font_face_t :: _cairo_font_face

/**
* cairo_glyph_t:
* @index: glyph index in the font. The exact interpretation of the
*      glyph index depends on the font technology being used.
* @x: the offset in the X direction between the origin used for
*     drawing or measuring the string and the origin of this glyph.
* @y: the offset in the Y direction between the origin used for
*     drawing or measuring the string and the origin of this glyph.
*
* The #cairo_glyph_t structure holds information about a single glyph
* when drawing or measuring text. A font is (in simple terms) a
* collection of shapes used to draw text. A glyph is one of these
* shapes. There can be multiple glyphs for a single character
* (alternates to be used in different contexts, for example), or a
* glyph can be a <firstterm>ligature</firstterm> of multiple
* characters. Cairo doesn't expose any way of converting input text
* into glyphs, so in order to use the Cairo interfaces that take
* arrays of glyphs, you must directly access the appropriate
* underlying font system.
*
* Note that the offsets given by @x and @y are not cumulative. When
* drawing or measuring text, each glyph is individually positioned
* with respect to the overall origin
*
* Since: 1.0
**/
glyph_t :: struct {
	index: c.ulong,
	x:     f64,
	y:     f64,
}

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	glyph_allocate :: proc(num_glyphs: i32) -> ^glyph_t ---
	glyph_free :: proc(glyphs: ^glyph_t) ---
}

/**
* cairo_text_cluster_t:
* @num_bytes: the number of bytes of UTF-8 text covered by cluster
* @num_glyphs: the number of glyphs covered by cluster
*
* The #cairo_text_cluster_t structure holds information about a single
* <firstterm>text cluster</firstterm>.  A text cluster is a minimal
* mapping of some glyphs corresponding to some UTF-8 text.
*
* For a cluster to be valid, both @num_bytes and @num_glyphs should
* be non-negative, and at least one should be non-zero.
* Note that clusters with zero glyphs are not as well supported as
* normal clusters.  For example, PDF rendering applications typically
* ignore those clusters when PDF text is being selected.
*
* See cairo_show_text_glyphs() for how clusters are used in advanced
* text operations.
*
* Since: 1.8
**/
text_cluster_t :: struct {
	num_bytes:  i32,
	num_glyphs: i32,
}

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	text_cluster_allocate :: proc(num_clusters: i32) -> ^text_cluster_t ---
	text_cluster_free :: proc(clusters: ^text_cluster_t) ---
}

/**
* cairo_text_cluster_flags_t:
* @CAIRO_TEXT_CLUSTER_FLAG_BACKWARD: The clusters in the cluster array
* map to glyphs in the glyph array from end to start. (Since 1.8)
*
* Specifies properties of a text cluster mapping.
*
* Since: 1.8
**/
_cairo_text_cluster_flags :: enum u32 {
	CAIRO_TEXT_CLUSTER_FLAG_BACKWARD = 1,
}

/**
* cairo_text_cluster_flags_t:
* @CAIRO_TEXT_CLUSTER_FLAG_BACKWARD: The clusters in the cluster array
* map to glyphs in the glyph array from end to start. (Since 1.8)
*
* Specifies properties of a text cluster mapping.
*
* Since: 1.8
**/
text_cluster_flags_t :: _cairo_text_cluster_flags

/**
* cairo_text_extents_t:
* @x_bearing: the horizontal distance from the origin to the
*   leftmost part of the glyphs as drawn. Positive if the
*   glyphs lie entirely to the right of the origin.
* @y_bearing: the vertical distance from the origin to the
*   topmost part of the glyphs as drawn. Positive only if the
*   glyphs lie completely below the origin; will usually be
*   negative.
* @width: width of the glyphs as drawn
* @height: height of the glyphs as drawn
* @x_advance:distance to advance in the X direction
*    after drawing these glyphs
* @y_advance: distance to advance in the Y direction
*   after drawing these glyphs. Will typically be zero except
*   for vertical text layout as found in East-Asian languages.
*
* The #cairo_text_extents_t structure stores the extents of a single
* glyph or a string of glyphs in user-space coordinates. Because text
* extents are in user-space coordinates, they are mostly, but not
* entirely, independent of the current transformation matrix. If you call
* <literal>cairo_scale(cr, 2.0, 2.0)</literal>, text will
* be drawn twice as big, but the reported text extents will not be
* doubled. They will change slightly due to hinting (so you can't
* assume that metrics are independent of the transformation matrix),
* but otherwise will remain unchanged.
*
* Since: 1.0
**/
text_extents_t :: struct {
	x_bearing: f64,
	y_bearing: f64,
	width:     f64,
	height:    f64,
	x_advance: f64,
	y_advance: f64,
}

/**
* cairo_font_extents_t:
* @ascent: the distance that the font extends above the baseline.
*          Note that this is not always exactly equal to the maximum
*          of the extents of all the glyphs in the font, but rather
*          is picked to express the font designer's intent as to
*          how the font should align with elements above it.
* @descent: the distance that the font extends below the baseline.
*           This value is positive for typical fonts that include
*           portions below the baseline. Note that this is not always
*           exactly equal to the maximum of the extents of all the
*           glyphs in the font, but rather is picked to express the
*           font designer's intent as to how the font should
*           align with elements below it.
* @height: the recommended vertical distance between baselines when
*          setting consecutive lines of text with the font. This
*          is greater than @ascent+@descent by a
*          quantity known as the <firstterm>line spacing</firstterm>
*          or <firstterm>external leading</firstterm>. When space
*          is at a premium, most fonts can be set with only
*          a distance of @ascent+@descent between lines.
* @max_x_advance: the maximum distance in the X direction that
*         the origin is advanced for any glyph in the font.
* @max_y_advance: the maximum distance in the Y direction that
*         the origin is advanced for any glyph in the font.
*         This will be zero for normal fonts used for horizontal
*         writing. (The scripts of East Asia are sometimes written
*         vertically.)
*
* The #cairo_font_extents_t structure stores metric information for
* a font. Values are given in the current user-space coordinate
* system.
*
* Because font metrics are in user-space coordinates, they are
* mostly, but not entirely, independent of the current transformation
* matrix. If you call <literal>cairo_scale(cr, 2.0, 2.0)</literal>,
* text will be drawn twice as big, but the reported text extents will
* not be doubled. They will change slightly due to hinting (so you
* can't assume that metrics are independent of the transformation
* matrix), but otherwise will remain unchanged.
*
* Since: 1.0
**/
font_extents_t :: struct {
	ascent:        f64,
	descent:       f64,
	height:        f64,
	max_x_advance: f64,
	max_y_advance: f64,
}

/**
* cairo_font_slant_t:
* @CAIRO_FONT_SLANT_NORMAL: Upright font style, since 1.0
* @CAIRO_FONT_SLANT_ITALIC: Italic font style, since 1.0
* @CAIRO_FONT_SLANT_OBLIQUE: Oblique font style, since 1.0
*
* Specifies variants of a font face based on their slant.
*
* Since: 1.0
**/
_cairo_font_slant :: enum u32 {
	NORMAL  = 0,
	ITALIC  = 1,
	OBLIQUE = 2,
}

/**
* cairo_font_slant_t:
* @CAIRO_FONT_SLANT_NORMAL: Upright font style, since 1.0
* @CAIRO_FONT_SLANT_ITALIC: Italic font style, since 1.0
* @CAIRO_FONT_SLANT_OBLIQUE: Oblique font style, since 1.0
*
* Specifies variants of a font face based on their slant.
*
* Since: 1.0
**/
font_slant_t :: _cairo_font_slant

/**
* cairo_font_weight_t:
* @CAIRO_FONT_WEIGHT_NORMAL: Normal font weight, since 1.0
* @CAIRO_FONT_WEIGHT_BOLD: Bold font weight, since 1.0
*
* Specifies variants of a font face based on their weight.
*
* Since: 1.0
**/
_cairo_font_weight :: enum u32 {
	NORMAL = 0,
	BOLD   = 1,
}

/**
* cairo_font_weight_t:
* @CAIRO_FONT_WEIGHT_NORMAL: Normal font weight, since 1.0
* @CAIRO_FONT_WEIGHT_BOLD: Bold font weight, since 1.0
*
* Specifies variants of a font face based on their weight.
*
* Since: 1.0
**/
font_weight_t :: _cairo_font_weight

/**
* cairo_subpixel_order_t:
* @CAIRO_SUBPIXEL_ORDER_DEFAULT: Use the default subpixel order for
*   for the target device, since 1.0
* @CAIRO_SUBPIXEL_ORDER_RGB: Subpixel elements are arranged horizontally
*   with red at the left, since 1.0
* @CAIRO_SUBPIXEL_ORDER_BGR:  Subpixel elements are arranged horizontally
*   with blue at the left, since 1.0
* @CAIRO_SUBPIXEL_ORDER_VRGB: Subpixel elements are arranged vertically
*   with red at the top, since 1.0
* @CAIRO_SUBPIXEL_ORDER_VBGR: Subpixel elements are arranged vertically
*   with blue at the top, since 1.0
*
* The subpixel order specifies the order of color elements within
* each pixel on the display device when rendering with an
* antialiasing mode of %CAIRO_ANTIALIAS_SUBPIXEL.
*
* Since: 1.0
**/
_cairo_subpixel_order :: enum u32 {
	DEFAULT = 0,
	RGB     = 1,
	BGR     = 2,
	VRGB    = 3,
	VBGR    = 4,
}

/**
* cairo_subpixel_order_t:
* @CAIRO_SUBPIXEL_ORDER_DEFAULT: Use the default subpixel order for
*   for the target device, since 1.0
* @CAIRO_SUBPIXEL_ORDER_RGB: Subpixel elements are arranged horizontally
*   with red at the left, since 1.0
* @CAIRO_SUBPIXEL_ORDER_BGR:  Subpixel elements are arranged horizontally
*   with blue at the left, since 1.0
* @CAIRO_SUBPIXEL_ORDER_VRGB: Subpixel elements are arranged vertically
*   with red at the top, since 1.0
* @CAIRO_SUBPIXEL_ORDER_VBGR: Subpixel elements are arranged vertically
*   with blue at the top, since 1.0
*
* The subpixel order specifies the order of color elements within
* each pixel on the display device when rendering with an
* antialiasing mode of %CAIRO_ANTIALIAS_SUBPIXEL.
*
* Since: 1.0
**/
subpixel_order_t :: _cairo_subpixel_order

/**
* cairo_hint_style_t:
* @CAIRO_HINT_STYLE_DEFAULT: Use the default hint style for
*   font backend and target device, since 1.0
* @CAIRO_HINT_STYLE_NONE: Do not hint outlines, since 1.0
* @CAIRO_HINT_STYLE_SLIGHT: Hint outlines slightly to improve
*   contrast while retaining good fidelity to the original
*   shapes, since 1.0
* @CAIRO_HINT_STYLE_MEDIUM: Hint outlines with medium strength
*   giving a compromise between fidelity to the original shapes
*   and contrast, since 1.0
* @CAIRO_HINT_STYLE_FULL: Hint outlines to maximize contrast, since 1.0
*
* Specifies the type of hinting to do on font outlines. Hinting
* is the process of fitting outlines to the pixel grid in order
* to improve the appearance of the result. Since hinting outlines
* involves distorting them, it also reduces the faithfulness
* to the original outline shapes. Not all of the outline hinting
* styles are supported by all font backends.
*
* New entries may be added in future versions.
*
* Since: 1.0
**/
_cairo_hint_style :: enum u32 {
	DEFAULT = 0,
	NONE    = 1,
	SLIGHT  = 2,
	MEDIUM  = 3,
	FULL    = 4,
}

/**
* cairo_hint_style_t:
* @CAIRO_HINT_STYLE_DEFAULT: Use the default hint style for
*   font backend and target device, since 1.0
* @CAIRO_HINT_STYLE_NONE: Do not hint outlines, since 1.0
* @CAIRO_HINT_STYLE_SLIGHT: Hint outlines slightly to improve
*   contrast while retaining good fidelity to the original
*   shapes, since 1.0
* @CAIRO_HINT_STYLE_MEDIUM: Hint outlines with medium strength
*   giving a compromise between fidelity to the original shapes
*   and contrast, since 1.0
* @CAIRO_HINT_STYLE_FULL: Hint outlines to maximize contrast, since 1.0
*
* Specifies the type of hinting to do on font outlines. Hinting
* is the process of fitting outlines to the pixel grid in order
* to improve the appearance of the result. Since hinting outlines
* involves distorting them, it also reduces the faithfulness
* to the original outline shapes. Not all of the outline hinting
* styles are supported by all font backends.
*
* New entries may be added in future versions.
*
* Since: 1.0
**/
hint_style_t :: _cairo_hint_style

/**
* cairo_hint_metrics_t:
* @CAIRO_HINT_METRICS_DEFAULT: Hint metrics in the default
*  manner for the font backend and target device, since 1.0
* @CAIRO_HINT_METRICS_OFF: Do not hint font metrics, since 1.0
* @CAIRO_HINT_METRICS_ON: Hint font metrics, since 1.0
*
* Specifies whether to hint font metrics; hinting font metrics
* means quantizing them so that they are integer values in
* device space. Doing this improves the consistency of
* letter and line spacing, however it also means that text
* will be laid out differently at different zoom factors.
*
* Since: 1.0
**/
_cairo_hint_metrics :: enum u32 {
	DEFAULT = 0,
	OFF     = 1,
	ON      = 2,
}

/**
* cairo_hint_metrics_t:
* @CAIRO_HINT_METRICS_DEFAULT: Hint metrics in the default
*  manner for the font backend and target device, since 1.0
* @CAIRO_HINT_METRICS_OFF: Do not hint font metrics, since 1.0
* @CAIRO_HINT_METRICS_ON: Hint font metrics, since 1.0
*
* Specifies whether to hint font metrics; hinting font metrics
* means quantizing them so that they are integer values in
* device space. Doing this improves the consistency of
* letter and line spacing, however it also means that text
* will be laid out differently at different zoom factors.
*
* Since: 1.0
**/
hint_metrics_t :: _cairo_hint_metrics

/**
* cairo_color_mode_t:
* @CAIRO_COLOR_MODE_DEFAULT: Use the default color mode for
* font backend and target device, since 1.18.
* @CAIRO_COLOR_MODE_NO_COLOR: Disable rendering color glyphs. Glyphs are
* always rendered as outline glyphs, since 1.18.
* @CAIRO_COLOR_MODE_COLOR: Enable rendering color glyphs. If the font
* contains a color presentation for a glyph, and when supported by
* the font backend, the glyph will be rendered in color, since 1.18.
*
* Specifies if color fonts are to be rendered using the color
* glyphs or outline glyphs. Glyphs that do not have a color
* presentation, and non-color fonts are not affected by this font
* option.
*
* Since: 1.18
**/
_cairo_color_mode :: enum u32 {
	DEFAULT  = 0,
	NO_COLOR = 1,
	COLOR    = 2,
}

/**
* cairo_color_mode_t:
* @CAIRO_COLOR_MODE_DEFAULT: Use the default color mode for
* font backend and target device, since 1.18.
* @CAIRO_COLOR_MODE_NO_COLOR: Disable rendering color glyphs. Glyphs are
* always rendered as outline glyphs, since 1.18.
* @CAIRO_COLOR_MODE_COLOR: Enable rendering color glyphs. If the font
* contains a color presentation for a glyph, and when supported by
* the font backend, the glyph will be rendered in color, since 1.18.
*
* Specifies if color fonts are to be rendered using the color
* glyphs or outline glyphs. Glyphs that do not have a color
* presentation, and non-color fonts are not affected by this font
* option.
*
* Since: 1.18
**/
color_mode_t :: _cairo_color_mode
_cairo_font_options :: struct {}

/**
* cairo_font_options_t:
*
* An opaque structure holding all options that are used when
* rendering fonts.
*
* Individual features of a #cairo_font_options_t can be set or
* accessed using functions named
* <function>cairo_font_options_set_<emphasis>feature_name</emphasis>()</function> and
* <function>cairo_font_options_get_<emphasis>feature_name</emphasis>()</function>, like
* cairo_font_options_set_antialias() and
* cairo_font_options_get_antialias().
*
* New features may be added to a #cairo_font_options_t in the
* future.  For this reason, cairo_font_options_copy(),
* cairo_font_options_equal(), cairo_font_options_merge(), and
* cairo_font_options_hash() should be used to copy, check
* for equality, merge, or compute a hash value of
* #cairo_font_options_t objects.
*
* Since: 1.0
**/
font_options_t :: _cairo_font_options

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	font_options_create :: proc() -> ^font_options_t ---
	font_options_copy :: proc(original: ^font_options_t) -> ^font_options_t ---
	font_options_destroy :: proc(options: ^font_options_t) ---
	font_options_status :: proc(options: ^font_options_t) -> status_t ---
	font_options_merge :: proc(options: ^font_options_t, other: ^font_options_t) ---
	font_options_equal :: proc(options: ^font_options_t, other: ^font_options_t) -> bool_t ---
	font_options_hash :: proc(options: ^font_options_t) -> c.ulong ---
	font_options_set_antialias :: proc(options: ^font_options_t, antialias: antialias_t) ---
	font_options_get_antialias :: proc(options: ^font_options_t) -> antialias_t ---
	font_options_set_subpixel_order :: proc(options: ^font_options_t, subpixel_order: subpixel_order_t) ---
	font_options_get_subpixel_order :: proc(options: ^font_options_t) -> subpixel_order_t ---
	font_options_set_hint_style :: proc(options: ^font_options_t, hint_style: hint_style_t) ---
	font_options_get_hint_style :: proc(options: ^font_options_t) -> hint_style_t ---
	font_options_set_hint_metrics :: proc(options: ^font_options_t, hint_metrics: hint_metrics_t) ---
	font_options_get_hint_metrics :: proc(options: ^font_options_t) -> hint_metrics_t ---
	font_options_get_variations :: proc(options: ^font_options_t) -> cstring ---
	font_options_set_variations :: proc(options: ^font_options_t, variations: cstring) ---
}

COLOR_PALETTE_DEFAULT :: 0

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	font_options_set_color_mode :: proc(options: ^font_options_t, color_mode: color_mode_t) ---
	font_options_get_color_mode :: proc(options: ^font_options_t) -> color_mode_t ---
	font_options_get_color_palette :: proc(options: ^font_options_t) -> u32 ---
	font_options_set_color_palette :: proc(options: ^font_options_t, palette_index: u32) ---
	font_options_set_custom_palette_color :: proc(options: ^font_options_t, index: u32, red: f64, green: f64, blue: f64, alpha: f64) ---
	font_options_get_custom_palette_color :: proc(options: ^font_options_t, index: u32, red: ^f64, green: ^f64, blue: ^f64, alpha: ^f64) -> status_t ---

	/* This interface is for dealing with text as text, not caring about the
	font object inside the cairo_t. */
	select_font_face :: proc(cr: ^cairo_t, family: cstring, slant: font_slant_t, weight: font_weight_t) ---
	set_font_size :: proc(cr: ^cairo_t, size: f64) ---
	set_font_matrix :: proc(cr: ^cairo_t, _matrix: ^matrix_t) ---
	get_font_matrix :: proc(cr: ^cairo_t, _matrix: ^matrix_t) ---
	set_font_options :: proc(cr: ^cairo_t, options: ^font_options_t) ---
	get_font_options :: proc(cr: ^cairo_t, options: ^font_options_t) ---
	set_font_face :: proc(cr: ^cairo_t, font_face: ^font_face_t) ---
	get_font_face :: proc(cr: ^cairo_t) -> ^font_face_t ---
	set_scaled_font :: proc(cr: ^cairo_t, scaled_font: ^scaled_font_t) ---
	get_scaled_font :: proc(cr: ^cairo_t) -> ^scaled_font_t ---
	show_text :: proc(cr: ^cairo_t, utf8: cstring) ---
	show_glyphs :: proc(cr: ^cairo_t, glyphs: [^]glyph_t, num_glyphs: i32) ---
	show_text_glyphs :: proc(cr: ^cairo_t, utf8: cstring, utf8_len: i32, glyphs: ^glyph_t, num_glyphs: i32, clusters: ^text_cluster_t, num_clusters: i32, cluster_flags: text_cluster_flags_t) ---
	text_path :: proc(cr: ^cairo_t, utf8: cstring) ---
	glyph_path :: proc(cr: ^cairo_t, glyphs: ^glyph_t, num_glyphs: i32) ---
	text_extents :: proc(cr: ^cairo_t, utf8: cstring, extents: ^text_extents_t) ---
	glyph_extents :: proc(cr: ^cairo_t, glyphs: [^]glyph_t, num_glyphs: i32, extents: ^text_extents_t) ---
	font_extents :: proc(cr: ^cairo_t, extents: ^font_extents_t) ---

	/* Generic identifier for a font style */
	font_face_reference :: proc(font_face: ^font_face_t) -> ^font_face_t ---
	font_face_destroy :: proc(font_face: ^font_face_t) ---
	font_face_get_reference_count :: proc(font_face: ^font_face_t) -> u32 ---
	font_face_status :: proc(font_face: ^font_face_t) -> status_t ---
}

/**
* cairo_font_type_t:
* @CAIRO_FONT_TYPE_TOY: The font was created using cairo's toy font api (Since: 1.2)
* @CAIRO_FONT_TYPE_FT: The font is of type FreeType (Since: 1.2)
* @CAIRO_FONT_TYPE_WIN32: The font is of type Win32 (Since: 1.2)
* @CAIRO_FONT_TYPE_QUARTZ: The font is of type Quartz (Since: 1.6, in 1.2 and
* 1.4 it was named CAIRO_FONT_TYPE_ATSUI)
* @CAIRO_FONT_TYPE_USER: The font was create using cairo's user font api (Since: 1.8)
* @CAIRO_FONT_TYPE_DWRITE: The font is of type Win32 DWrite (Since: 1.18)
*
* #cairo_font_type_t is used to describe the type of a given font
* face or scaled font. The font types are also known as "font
* backends" within cairo.
*
* The type of a font face is determined by the function used to
* create it, which will generally be of the form
* <function>cairo_<emphasis>type</emphasis>_font_face_create(<!-- -->)</function>.
* The font face type can be queried with cairo_font_face_get_type()
*
* The various #cairo_font_face_t functions can be used with a font face
* of any type.
*
* The type of a scaled font is determined by the type of the font
* face passed to cairo_scaled_font_create(). The scaled font type can
* be queried with cairo_scaled_font_get_type()
*
* The various #cairo_scaled_font_t functions can be used with scaled
* fonts of any type, but some font backends also provide
* type-specific functions that must only be called with a scaled font
* of the appropriate type. These functions have names that begin with
* <function>cairo_<emphasis>type</emphasis>_scaled_font(<!-- -->)</function>
* such as cairo_ft_scaled_font_lock_face().
*
* The behavior of calling a type-specific function with a scaled font
* of the wrong type is undefined.
*
* New entries may be added in future versions.
*
* Since: 1.2
**/
_cairo_font_type :: enum u32 {
	TOY    = 0,
	FT     = 1,
	WIN32  = 2,
	QUARTZ = 3,
	USER   = 4,
	DWRITE = 5,
}

/**
* cairo_font_type_t:
* @CAIRO_FONT_TYPE_TOY: The font was created using cairo's toy font api (Since: 1.2)
* @CAIRO_FONT_TYPE_FT: The font is of type FreeType (Since: 1.2)
* @CAIRO_FONT_TYPE_WIN32: The font is of type Win32 (Since: 1.2)
* @CAIRO_FONT_TYPE_QUARTZ: The font is of type Quartz (Since: 1.6, in 1.2 and
* 1.4 it was named CAIRO_FONT_TYPE_ATSUI)
* @CAIRO_FONT_TYPE_USER: The font was create using cairo's user font api (Since: 1.8)
* @CAIRO_FONT_TYPE_DWRITE: The font is of type Win32 DWrite (Since: 1.18)
*
* #cairo_font_type_t is used to describe the type of a given font
* face or scaled font. The font types are also known as "font
* backends" within cairo.
*
* The type of a font face is determined by the function used to
* create it, which will generally be of the form
* <function>cairo_<emphasis>type</emphasis>_font_face_create(<!-- -->)</function>.
* The font face type can be queried with cairo_font_face_get_type()
*
* The various #cairo_font_face_t functions can be used with a font face
* of any type.
*
* The type of a scaled font is determined by the type of the font
* face passed to cairo_scaled_font_create(). The scaled font type can
* be queried with cairo_scaled_font_get_type()
*
* The various #cairo_scaled_font_t functions can be used with scaled
* fonts of any type, but some font backends also provide
* type-specific functions that must only be called with a scaled font
* of the appropriate type. These functions have names that begin with
* <function>cairo_<emphasis>type</emphasis>_scaled_font(<!-- -->)</function>
* such as cairo_ft_scaled_font_lock_face().
*
* The behavior of calling a type-specific function with a scaled font
* of the wrong type is undefined.
*
* New entries may be added in future versions.
*
* Since: 1.2
**/
font_type_t :: _cairo_font_type

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	font_face_get_type :: proc(font_face: ^font_face_t) -> font_type_t ---
	font_face_get_user_data :: proc(font_face: ^font_face_t, key: ^user_data_key_t) -> rawptr ---
	font_face_set_user_data :: proc(font_face: ^font_face_t, key: ^user_data_key_t, user_data: rawptr, destroy: destroy_func_t) -> status_t ---

	/* Portable interface to general font features. */
	scaled_font_create :: proc(font_face: ^font_face_t, font_matrix: ^matrix_t, ctm: ^matrix_t, options: ^font_options_t) -> ^scaled_font_t ---
	scaled_font_reference :: proc(scaled_font: ^scaled_font_t) -> ^scaled_font_t ---
	scaled_font_destroy :: proc(scaled_font: ^scaled_font_t) ---
	scaled_font_get_reference_count :: proc(scaled_font: ^scaled_font_t) -> u32 ---
	scaled_font_status :: proc(scaled_font: ^scaled_font_t) -> status_t ---
	scaled_font_get_type :: proc(scaled_font: ^scaled_font_t) -> font_type_t ---
	scaled_font_get_user_data :: proc(scaled_font: ^scaled_font_t, key: ^user_data_key_t) -> rawptr ---
	scaled_font_set_user_data :: proc(scaled_font: ^scaled_font_t, key: ^user_data_key_t, user_data: rawptr, destroy: destroy_func_t) -> status_t ---
	scaled_font_extents :: proc(scaled_font: ^scaled_font_t, extents: ^font_extents_t) ---
	scaled_font_text_extents :: proc(scaled_font: ^scaled_font_t, utf8: cstring, extents: ^text_extents_t) ---
	scaled_font_glyph_extents :: proc(scaled_font: ^scaled_font_t, glyphs: ^glyph_t, num_glyphs: i32, extents: ^text_extents_t) ---
	scaled_font_text_to_glyphs :: proc(scaled_font: ^scaled_font_t, x: f64, y: f64, utf8: cstring, utf8_len: i32, glyphs: ^[^]glyph_t, num_glyphs: ^i32, clusters: ^^text_cluster_t, num_clusters: ^i32, cluster_flags: ^text_cluster_flags_t) -> status_t ---
	scaled_font_get_font_face :: proc(scaled_font: ^scaled_font_t) -> ^font_face_t ---
	scaled_font_get_font_matrix :: proc(scaled_font: ^scaled_font_t, font_matrix: ^matrix_t) ---
	scaled_font_get_ctm :: proc(scaled_font: ^scaled_font_t, ctm: ^matrix_t) ---
	scaled_font_get_scale_matrix :: proc(scaled_font: ^scaled_font_t, scale_matrix: ^matrix_t) ---
	scaled_font_get_font_options :: proc(scaled_font: ^scaled_font_t, options: ^font_options_t) ---

	/* Toy fonts */
	toy_font_face_create :: proc(family: cstring, slant: font_slant_t, weight: font_weight_t) -> ^font_face_t ---
	toy_font_face_get_family :: proc(font_face: ^font_face_t) -> cstring ---
	toy_font_face_get_slant :: proc(font_face: ^font_face_t) -> font_slant_t ---
	toy_font_face_get_weight :: proc(font_face: ^font_face_t) -> font_weight_t ---

	/* User fonts */
	user_font_face_create :: proc() -> ^font_face_t ---
}

/**
* cairo_user_scaled_font_init_func_t:
* @scaled_font: the scaled-font being created
* @cr: a cairo context, in font space
* @extents: font extents to fill in, in font space
*
* #cairo_user_scaled_font_init_func_t is the type of function which is
* called when a scaled-font needs to be created for a user font-face.
*
* The cairo context @cr is not used by the caller, but is prepared in font
* space, similar to what the cairo contexts passed to the render_glyph
* method will look like.  The callback can use this context for extents
* computation for example.  After the callback is called, @cr is checked
* for any error status.
*
* The @extents argument is where the user font sets the font extents for
* @scaled_font.  It is in font space, which means that for most cases its
* ascent and descent members should add to 1.0.  @extents is preset to
* hold a value of 1.0 for ascent, height, and max_x_advance, and 0.0 for
* descent and max_y_advance members.
*
* The callback is optional.  If not set, default font extents as described
* in the previous paragraph will be used.
*
* Note that @scaled_font is not fully initialized at this
* point and trying to use it for text operations in the callback will result
* in deadlock.
*
* Returns: %CAIRO_STATUS_SUCCESS upon success, or an error status on error.
*
* Since: 1.8
**/
user_scaled_font_init_func_t :: proc "c" (
	scaled_font: ^scaled_font_t,
	cr: ^cairo_t,
	extents: ^font_extents_t,
) -> status_t

/**
* cairo_user_scaled_font_render_glyph_func_t:
* @scaled_font: user scaled-font
* @glyph: glyph code to render
* @cr: cairo context to draw to, in font space
* @extents: glyph extents to fill in, in font space
*
* #cairo_user_scaled_font_render_glyph_func_t is the type of function which
* is called when a user scaled-font needs to render a glyph.
*
* The callback is mandatory, and expected to draw the glyph with code @glyph to
* the cairo context @cr.  @cr is prepared such that the glyph drawing is done in
* font space.  That is, the matrix set on @cr is the scale matrix of @scaled_font.
* The @extents argument is where the user font sets the font extents for
* @scaled_font.  However, if user prefers to draw in user space, they can
* achieve that by changing the matrix on @cr.
*
* All cairo rendering operations to @cr are permitted. However, when
* this callback is set with
* cairo_user_font_face_set_render_glyph_func(), the result is
* undefined if any source other than the default source on @cr is
* used.  That means, glyph bitmaps should be rendered using
* cairo_mask() instead of cairo_paint().
*
* When this callback is set with
* cairo_user_font_face_set_render_color_glyph_func(), the default
* source is black. Setting the source is a valid
* operation. cairo_user_scaled_font_get_foreground_marker() or
* cairo_user_scaled_font_get_foreground_source() may be called to
* obtain the current source at the time the glyph is rendered.
*
* Other non-default settings on @cr include a font size of 1.0 (given that
* it is set up to be in font space), and font options corresponding to
* @scaled_font.
*
* The @extents argument is preset to have <literal>x_bearing</literal>,
* <literal>width</literal>, and <literal>y_advance</literal> of zero,
* <literal>y_bearing</literal> set to <literal>-font_extents.ascent</literal>,
* <literal>height</literal> to <literal>font_extents.ascent+font_extents.descent</literal>,
* and <literal>x_advance</literal> to <literal>font_extents.max_x_advance</literal>.
* The only field user needs to set in majority of cases is
* <literal>x_advance</literal>.
* If the <literal>width</literal> field is zero upon the callback returning
* (which is its preset value), the glyph extents are automatically computed
* based on the drawings done to @cr.  This is in most cases exactly what the
* desired behavior is.  However, if for any reason the callback sets the
* extents, it must be ink extents, and include the extents of all drawing
* done to @cr in the callback.
*
* Where both color and non-color callbacks has been set using
* cairo_user_font_face_set_render_color_glyph_func(), and
* cairo_user_font_face_set_render_glyph_func(), the color glyph
* callback will be called first. If the color glyph callback returns
* %CAIRO_STATUS_USER_FONT_NOT_IMPLEMENTED, any drawing operations are
* discarded and the non-color callback will be called. This is the
* only case in which the %CAIRO_STATUS_USER_FONT_NOT_IMPLEMENTED may
* be returned from a render callback. This fallback sequence allows a
* user font face to contain a combination of both color and non-color
* glyphs.
*
* Returns: %CAIRO_STATUS_SUCCESS upon success,
* %CAIRO_STATUS_USER_FONT_NOT_IMPLEMENTED if fallback options should be tried,
* or %CAIRO_STATUS_USER_FONT_ERROR or any other error status on error.
*
* Since: 1.8
**/
user_scaled_font_render_glyph_func_t :: proc "c" (
	scaled_font: ^scaled_font_t,
	glyph: c.ulong,
	cr: ^cairo_t,
	extents: ^text_extents_t,
) -> status_t

/**
* cairo_user_scaled_font_text_to_glyphs_func_t:
* @scaled_font: the scaled-font being created
* @utf8: a string of text encoded in UTF-8
* @utf8_len: length of @utf8 in bytes
* @glyphs: pointer to array of glyphs to fill, in font space
* @num_glyphs: pointer to number of glyphs
* @clusters: pointer to array of cluster mapping information to fill, or %NULL
* @num_clusters: pointer to number of clusters
* @cluster_flags: pointer to location to store cluster flags corresponding to the
*                 output @clusters
*
* #cairo_user_scaled_font_text_to_glyphs_func_t is the type of function which
* is called to convert input text to an array of glyphs.  This is used by the
* cairo_show_text() operation.
*
* Using this callback the user-font has full control on glyphs and their
* positions.  That means, it allows for features like ligatures and kerning,
* as well as complex <firstterm>shaping</firstterm> required for scripts like
* Arabic and Indic.
*
* The @num_glyphs argument is preset to the number of glyph entries available
* in the @glyphs buffer. If the @glyphs buffer is %NULL, the value of
* @num_glyphs will be zero.  If the provided glyph array is too short for
* the conversion (or for convenience), a new glyph array may be allocated
* using cairo_glyph_allocate() and placed in @glyphs.  Upon return,
* @num_glyphs should contain the number of generated glyphs.  If the value
* @glyphs points at has changed after the call, the caller will free the
* allocated glyph array using cairo_glyph_free().  The caller will also free
* the original value of @glyphs, so the callback shouldn't do so.
* The callback should populate the glyph indices and positions (in font space)
* assuming that the text is to be shown at the origin.
*
* If @clusters is not %NULL, @num_clusters and @cluster_flags are also
* non-%NULL, and cluster mapping should be computed. The semantics of how
* cluster array allocation works is similar to the glyph array.  That is,
* if @clusters initially points to a non-%NULL value, that array may be used
* as a cluster buffer, and @num_clusters points to the number of cluster
* entries available there.  If the provided cluster array is too short for
* the conversion (or for convenience), a new cluster array may be allocated
* using cairo_text_cluster_allocate() and placed in @clusters.  In this case,
* the original value of @clusters will still be freed by the caller.  Upon
* return, @num_clusters should contain the number of generated clusters.
* If the value @clusters points at has changed after the call, the caller
* will free the allocated cluster array using cairo_text_cluster_free().
*
* The callback is optional.  If @num_glyphs is negative upon
* the callback returning or if the return value
* is %CAIRO_STATUS_USER_FONT_NOT_IMPLEMENTED, the unicode_to_glyph callback
* is tried.  See #cairo_user_scaled_font_unicode_to_glyph_func_t.
*
* Note: While cairo does not impose any limitation on glyph indices,
* some applications may assume that a glyph index fits in a 16-bit
* unsigned integer.  As such, it is advised that user-fonts keep their
* glyphs in the 0 to 65535 range.  Furthermore, some applications may
* assume that glyph 0 is a special glyph-not-found glyph.  User-fonts
* are advised to use glyph 0 for such purposes and do not use that
* glyph value for other purposes.
*
* Returns: %CAIRO_STATUS_SUCCESS upon success,
* %CAIRO_STATUS_USER_FONT_NOT_IMPLEMENTED if fallback options should be tried,
* or %CAIRO_STATUS_USER_FONT_ERROR or any other error status on error.
*
* Since: 1.8
**/
user_scaled_font_text_to_glyphs_func_t :: proc "c" (
	scaled_font: ^scaled_font_t,
	utf8: cstring,
	utf8_len: i32,
	glyphs: ^^glyph_t,
	num_glyphs: ^i32,
	clusters: ^^text_cluster_t,
	num_clusters: ^i32,
	cluster_flags: ^text_cluster_flags_t,
) -> status_t

/**
* cairo_user_scaled_font_unicode_to_glyph_func_t:
* @scaled_font: the scaled-font being created
* @unicode: input unicode character code-point
* @glyph_index: output glyph index
*
* #cairo_user_scaled_font_unicode_to_glyph_func_t is the type of function which
* is called to convert an input Unicode character to a single glyph.
* This is used by the cairo_show_text() operation.
*
* This callback is used to provide the same functionality as the
* text_to_glyphs callback does (see #cairo_user_scaled_font_text_to_glyphs_func_t)
* but has much less control on the output,
* in exchange for increased ease of use.  The inherent assumption to using
* this callback is that each character maps to one glyph, and that the
* mapping is context independent.  It also assumes that glyphs are positioned
* according to their advance width.  These mean no ligatures, kerning, or
* complex scripts can be implemented using this callback.
*
* The callback is optional, and only used if text_to_glyphs callback is not
* set or fails to return glyphs.  If this callback is not set or if it returns
* %CAIRO_STATUS_USER_FONT_NOT_IMPLEMENTED, an identity mapping from Unicode
* code-points to glyph indices is assumed.
*
* Note: While cairo does not impose any limitation on glyph indices,
* some applications may assume that a glyph index fits in a 16-bit
* unsigned integer.  As such, it is advised that user-fonts keep their
* glyphs in the 0 to 65535 range.  Furthermore, some applications may
* assume that glyph 0 is a special glyph-not-found glyph.  User-fonts
* are advised to use glyph 0 for such purposes and do not use that
* glyph value for other purposes.
*
* Returns: %CAIRO_STATUS_SUCCESS upon success,
* %CAIRO_STATUS_USER_FONT_NOT_IMPLEMENTED if fallback options should be tried,
* or %CAIRO_STATUS_USER_FONT_ERROR or any other error status on error.
*
* Since: 1.8
**/
user_scaled_font_unicode_to_glyph_func_t :: proc "c" (
	scaled_font: ^scaled_font_t,
	unicode: c.ulong,
	glyph_index: ^c.ulong,
) -> status_t

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	/* User-font method setters */
	user_font_face_set_init_func :: proc(font_face: ^font_face_t, init_func: user_scaled_font_init_func_t) ---
	user_font_face_set_render_glyph_func :: proc(font_face: ^font_face_t, render_glyph_func: user_scaled_font_render_glyph_func_t) ---
	user_font_face_set_render_color_glyph_func :: proc(font_face: ^font_face_t, render_glyph_func: user_scaled_font_render_glyph_func_t) ---
	user_font_face_set_text_to_glyphs_func :: proc(font_face: ^font_face_t, text_to_glyphs_func: user_scaled_font_text_to_glyphs_func_t) ---
	user_font_face_set_unicode_to_glyph_func :: proc(font_face: ^font_face_t, unicode_to_glyph_func: user_scaled_font_unicode_to_glyph_func_t) ---

	/* User-font method getters */
	user_font_face_get_init_func :: proc(font_face: ^font_face_t) -> user_scaled_font_init_func_t ---
	user_font_face_get_render_glyph_func :: proc(font_face: ^font_face_t) -> user_scaled_font_render_glyph_func_t ---
	user_font_face_get_render_color_glyph_func :: proc(font_face: ^font_face_t) -> user_scaled_font_render_glyph_func_t ---
	user_font_face_get_text_to_glyphs_func :: proc(font_face: ^font_face_t) -> user_scaled_font_text_to_glyphs_func_t ---
	user_font_face_get_unicode_to_glyph_func :: proc(font_face: ^font_face_t) -> user_scaled_font_unicode_to_glyph_func_t ---
	user_scaled_font_get_foreground_marker :: proc(scaled_font: ^scaled_font_t) -> ^pattern_t ---
	user_scaled_font_get_foreground_source :: proc(scaled_font: ^scaled_font_t) -> ^pattern_t ---

	/* Query functions */
	get_operator :: proc(cr: ^cairo_t) -> operator_t ---
	get_source :: proc(cr: ^cairo_t) -> ^pattern_t ---
	get_tolerance :: proc(cr: ^cairo_t) -> f64 ---
	get_antialias :: proc(cr: ^cairo_t) -> antialias_t ---
	has_current_point :: proc(cr: ^cairo_t) -> bool_t ---
	get_current_point :: proc(cr: ^cairo_t, x: ^f64, y: ^f64) ---
	get_fill_rule :: proc(cr: ^cairo_t) -> fill_rule_t ---
	get_line_width :: proc(cr: ^cairo_t) -> f64 ---
	get_hairline :: proc(cr: ^cairo_t) -> bool_t ---
	get_line_cap :: proc(cr: ^cairo_t) -> line_cap_t ---
	get_line_join :: proc(cr: ^cairo_t) -> line_join_t ---
	get_miter_limit :: proc(cr: ^cairo_t) -> f64 ---
	get_dash_count :: proc(cr: ^cairo_t) -> i32 ---
	get_dash :: proc(cr: ^cairo_t, dashes: ^f64, offset: ^f64) ---
	get_matrix :: proc(cr: ^cairo_t, _matrix: ^matrix_t) ---
	get_target :: proc(cr: ^cairo_t) -> ^surface_t ---
	get_group_target :: proc(cr: ^cairo_t) -> ^surface_t ---
}

/**
* cairo_path_data_type_t:
* @CAIRO_PATH_MOVE_TO: A move-to operation, since 1.0
* @CAIRO_PATH_LINE_TO: A line-to operation, since 1.0
* @CAIRO_PATH_CURVE_TO: A curve-to operation, since 1.0
* @CAIRO_PATH_CLOSE_PATH: A close-path operation, since 1.0
*
* #cairo_path_data_t is used to describe the type of one portion
* of a path when represented as a #cairo_path_t.
* See #cairo_path_data_t for details.
*
* Since: 1.0
**/
_cairo_path_data_type :: enum u32 {
	MOVE_TO    = 0,
	LINE_TO    = 1,
	CURVE_TO   = 2,
	CLOSE_PATH = 3,
}

/**
* cairo_path_data_type_t:
* @CAIRO_PATH_MOVE_TO: A move-to operation, since 1.0
* @CAIRO_PATH_LINE_TO: A line-to operation, since 1.0
* @CAIRO_PATH_CURVE_TO: A curve-to operation, since 1.0
* @CAIRO_PATH_CLOSE_PATH: A close-path operation, since 1.0
*
* #cairo_path_data_t is used to describe the type of one portion
* of a path when represented as a #cairo_path_t.
* See #cairo_path_data_t for details.
*
* Since: 1.0
**/
path_data_type_t :: _cairo_path_data_type

/**
* cairo_path_data_t:
*
* #cairo_path_data_t is used to represent the path data inside a
* #cairo_path_t.
*
* The data structure is designed to try to balance the demands of
* efficiency and ease-of-use. A path is represented as an array of
* #cairo_path_data_t, which is a union of headers and points.
*
* Each portion of the path is represented by one or more elements in
* the array, (one header followed by 0 or more points). The length
* value of the header is the number of array elements for the current
* portion including the header, (ie. length == 1 + # of points), and
* where the number of points for each element type is as follows:
*
* <programlisting>
*     %CAIRO_PATH_MOVE_TO:     1 point
*     %CAIRO_PATH_LINE_TO:     1 point
*     %CAIRO_PATH_CURVE_TO:    3 points
*     %CAIRO_PATH_CLOSE_PATH:  0 points
* </programlisting>
*
* The semantics and ordering of the coordinate values are consistent
* with cairo_move_to(), cairo_line_to(), cairo_curve_to(), and
* cairo_close_path().
*
* Here is sample code for iterating through a #cairo_path_t:
*
* <informalexample><programlisting>
*      int i;
*      cairo_path_t *path;
*      cairo_path_data_t *data;
* &nbsp;
*      path = cairo_copy_path (cr);
* &nbsp;
*      for (i=0; i < path->num_data; i += path->data[i].header.length) {
*          data = &amp;path->data[i];
*          switch (data->header.type) {
*          case CAIRO_PATH_MOVE_TO:
*              do_move_to_things (data[1].point.x, data[1].point.y);
*              break;
*          case CAIRO_PATH_LINE_TO:
*              do_line_to_things (data[1].point.x, data[1].point.y);
*              break;
*          case CAIRO_PATH_CURVE_TO:
*              do_curve_to_things (data[1].point.x, data[1].point.y,
*                                  data[2].point.x, data[2].point.y,
*                                  data[3].point.x, data[3].point.y);
*              break;
*          case CAIRO_PATH_CLOSE_PATH:
*              do_close_path_things ();
*              break;
*          }
*      }
*      cairo_path_destroy (path);
* </programlisting></informalexample>
*
* As of cairo 1.4, cairo does not mind if there are more elements in
* a portion of the path than needed.  Such elements can be used by
* users of the cairo API to hold extra values in the path data
* structure.  For this reason, it is recommended that applications
* always use <literal>data->header.length</literal> to
* iterate over the path data, instead of hardcoding the number of
* elements for each element type.
*
* Since: 1.0
**/
path_data_t :: _cairo_path_data_t

_cairo_path_data_t :: struct #raw_union {
	header: struct {
		type:   path_data_type_t,
		length: i32,
	},
	point:  struct {
		x, y: f64,
	},
}

/**
* cairo_path_t:
* @status: the current error status
* @data: the elements in the path
* @num_data: the number of elements in the data array
*
* A data structure for holding a path. This data structure serves as
* the return value for cairo_copy_path() and
* cairo_copy_path_flat() as well the input value for
* cairo_append_path().
*
* See #cairo_path_data_t for hints on how to iterate over the
* actual data within the path.
*
* The num_data member gives the number of elements in the data
* array. This number is larger than the number of independent path
* portions (defined in #cairo_path_data_type_t), since the data
* includes both headers and coordinates for each portion.
*
* Since: 1.0
**/
path :: struct {
	status:   status_t,
	data:     ^path_data_t,
	num_data: i32,
}

/**
* cairo_path_t:
* @status: the current error status
* @data: the elements in the path
* @num_data: the number of elements in the data array
*
* A data structure for holding a path. This data structure serves as
* the return value for cairo_copy_path() and
* cairo_copy_path_flat() as well the input value for
* cairo_append_path().
*
* See #cairo_path_data_t for hints on how to iterate over the
* actual data within the path.
*
* The num_data member gives the number of elements in the data
* array. This number is larger than the number of independent path
* portions (defined in #cairo_path_data_type_t), since the data
* includes both headers and coordinates for each portion.
*
* Since: 1.0
**/
path_t :: path

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	copy_path :: proc(cr: ^cairo_t) -> ^path_t ---
	copy_path_flat :: proc(cr: ^cairo_t) -> ^path_t ---
	append_path :: proc(cr: ^cairo_t, path: ^path_t) ---
	path_destroy :: proc(path: ^path_t) ---

	/* Error status queries */
	status :: proc(cr: ^cairo_t) -> status_t ---
	status_to_string :: proc(status: status_t) -> cstring ---

	/* Backend device manipulation */
	device_reference :: proc(device: ^device_t) -> ^device_t ---
}

/**
* cairo_device_type_t:
* @CAIRO_DEVICE_TYPE_DRM: The device is of type Direct Render Manager, since 1.10
* @CAIRO_DEVICE_TYPE_GL: The device is of type OpenGL, since 1.10
* @CAIRO_DEVICE_TYPE_SCRIPT: The device is of type script, since 1.10
* @CAIRO_DEVICE_TYPE_XCB: The device is of type xcb, since 1.10
* @CAIRO_DEVICE_TYPE_XLIB: The device is of type xlib, since 1.10
* @CAIRO_DEVICE_TYPE_XML: The device is of type XML, since 1.10
* @CAIRO_DEVICE_TYPE_COGL: The device is of type cogl, since 1.12
* @CAIRO_DEVICE_TYPE_WIN32: The device is of type win32, since 1.12
* @CAIRO_DEVICE_TYPE_INVALID: The device is invalid, since 1.10
*
* #cairo_device_type_t is used to describe the type of a given
* device. The devices types are also known as "backends" within cairo.
*
* The device type can be queried with cairo_device_get_type()
*
* The various #cairo_device_t functions can be used with devices of
* any type, but some backends also provide type-specific functions
* that must only be called with a device of the appropriate
* type. These functions have names that begin with
* <literal>cairo_<emphasis>type</emphasis>_device</literal> such as
* cairo_xcb_device_debug_cap_xrender_version().
*
* The behavior of calling a type-specific function with a device of
* the wrong type is undefined.
*
* New entries may be added in future versions.
*
* Since: 1.10
**/
_cairo_device_type :: enum i32 {
	DRM     = 0,
	GL      = 1,
	SCRIPT  = 2,
	XCB     = 3,
	XLIB    = 4,
	XML     = 5,
	COGL    = 6,
	WIN32   = 7,
	INVALID = -1,
}

/**
* cairo_device_type_t:
* @CAIRO_DEVICE_TYPE_DRM: The device is of type Direct Render Manager, since 1.10
* @CAIRO_DEVICE_TYPE_GL: The device is of type OpenGL, since 1.10
* @CAIRO_DEVICE_TYPE_SCRIPT: The device is of type script, since 1.10
* @CAIRO_DEVICE_TYPE_XCB: The device is of type xcb, since 1.10
* @CAIRO_DEVICE_TYPE_XLIB: The device is of type xlib, since 1.10
* @CAIRO_DEVICE_TYPE_XML: The device is of type XML, since 1.10
* @CAIRO_DEVICE_TYPE_COGL: The device is of type cogl, since 1.12
* @CAIRO_DEVICE_TYPE_WIN32: The device is of type win32, since 1.12
* @CAIRO_DEVICE_TYPE_INVALID: The device is invalid, since 1.10
*
* #cairo_device_type_t is used to describe the type of a given
* device. The devices types are also known as "backends" within cairo.
*
* The device type can be queried with cairo_device_get_type()
*
* The various #cairo_device_t functions can be used with devices of
* any type, but some backends also provide type-specific functions
* that must only be called with a device of the appropriate
* type. These functions have names that begin with
* <literal>cairo_<emphasis>type</emphasis>_device</literal> such as
* cairo_xcb_device_debug_cap_xrender_version().
*
* The behavior of calling a type-specific function with a device of
* the wrong type is undefined.
*
* New entries may be added in future versions.
*
* Since: 1.10
**/
device_type_t :: _cairo_device_type

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	device_get_type :: proc(device: ^device_t) -> device_type_t ---
	device_status :: proc(device: ^device_t) -> status_t ---
	device_acquire :: proc(device: ^device_t) -> status_t ---
	device_release :: proc(device: ^device_t) ---
	device_flush :: proc(device: ^device_t) ---
	device_finish :: proc(device: ^device_t) ---
	device_destroy :: proc(device: ^device_t) ---
	device_get_reference_count :: proc(device: ^device_t) -> u32 ---
	device_get_user_data :: proc(device: ^device_t, key: ^user_data_key_t) -> rawptr ---
	device_set_user_data :: proc(device: ^device_t, key: ^user_data_key_t, user_data: rawptr, destroy: destroy_func_t) -> status_t ---

	/* Surface manipulation */
	surface_create_similar :: proc(other: ^surface_t, content: content_t, width: i32, height: i32) -> ^surface_t ---
	surface_create_similar_image :: proc(other: ^surface_t, format: format_t, width: i32, height: i32) -> ^surface_t ---
	surface_map_to_image :: proc(surface: ^surface_t, extents: ^rectangle_int_t) -> ^surface_t ---
	surface_unmap_image :: proc(surface: ^surface_t, image: ^surface_t) ---
	surface_create_for_rectangle :: proc(target: ^surface_t, x: f64, y: f64, width: f64, height: f64) -> ^surface_t ---
}

/**
* cairo_surface_observer_mode_t:
* @CAIRO_SURFACE_OBSERVER_NORMAL: no recording is done
* @CAIRO_SURFACE_OBSERVER_RECORD_OPERATIONS: operations are recorded
*
* Whether operations should be recorded.
*
* Since: 1.12
**/
surface_observer_mode_t :: enum u32 {
	NORMAL            = 0,
	RECORD_OPERATIONS = 1,
}

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	surface_create_observer :: proc(target: ^surface_t, mode: surface_observer_mode_t) -> ^surface_t ---
}

/**
* cairo_surface_observer_callback_t:
* @observer: the #cairo_surface_observer_t
* @target: the observed surface
* @data: closure used when adding the callback
*
* A generic callback function for surface operations.
*
* Since: 1.12
**/
surface_observer_callback_t :: proc "c" (observer: ^surface_t, target: ^surface_t, data: rawptr)

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	surface_observer_add_paint_callback :: proc(abstract_surface: ^surface_t, func: surface_observer_callback_t, data: rawptr) -> status_t ---
	surface_observer_add_mask_callback :: proc(abstract_surface: ^surface_t, func: surface_observer_callback_t, data: rawptr) -> status_t ---
	surface_observer_add_fill_callback :: proc(abstract_surface: ^surface_t, func: surface_observer_callback_t, data: rawptr) -> status_t ---
	surface_observer_add_stroke_callback :: proc(abstract_surface: ^surface_t, func: surface_observer_callback_t, data: rawptr) -> status_t ---
	surface_observer_add_glyphs_callback :: proc(abstract_surface: ^surface_t, func: surface_observer_callback_t, data: rawptr) -> status_t ---
	surface_observer_add_flush_callback :: proc(abstract_surface: ^surface_t, func: surface_observer_callback_t, data: rawptr) -> status_t ---
	surface_observer_add_finish_callback :: proc(abstract_surface: ^surface_t, func: surface_observer_callback_t, data: rawptr) -> status_t ---
	surface_observer_print :: proc(abstract_surface: ^surface_t, write_func: write_func_t, closure: rawptr) -> status_t ---
	surface_observer_elapsed :: proc(abstract_surface: ^surface_t) -> f64 ---
	device_observer_print :: proc(abstract_device: ^device_t, write_func: write_func_t, closure: rawptr) -> status_t ---
	device_observer_elapsed :: proc(abstract_device: ^device_t) -> f64 ---
	device_observer_paint_elapsed :: proc(abstract_device: ^device_t) -> f64 ---
	device_observer_mask_elapsed :: proc(abstract_device: ^device_t) -> f64 ---
	device_observer_fill_elapsed :: proc(abstract_device: ^device_t) -> f64 ---
	device_observer_stroke_elapsed :: proc(abstract_device: ^device_t) -> f64 ---
	device_observer_glyphs_elapsed :: proc(abstract_device: ^device_t) -> f64 ---
	surface_reference :: proc(surface: ^surface_t) -> ^surface_t ---
	surface_finish :: proc(surface: ^surface_t) ---
	surface_destroy :: proc(surface: ^surface_t) ---
	surface_get_device :: proc(surface: ^surface_t) -> ^device_t ---
	surface_get_reference_count :: proc(surface: ^surface_t) -> u32 ---
	surface_status :: proc(surface: ^surface_t) -> status_t ---
}

/**
* cairo_surface_type_t:
* @CAIRO_SURFACE_TYPE_IMAGE: The surface is of type image, since 1.2
* @CAIRO_SURFACE_TYPE_PDF: The surface is of type pdf, since 1.2
* @CAIRO_SURFACE_TYPE_PS: The surface is of type ps, since 1.2
* @CAIRO_SURFACE_TYPE_XLIB: The surface is of type xlib, since 1.2
* @CAIRO_SURFACE_TYPE_XCB: The surface is of type xcb, since 1.2
* @CAIRO_SURFACE_TYPE_GLITZ: The surface is of type glitz, since 1.2, deprecated 1.18
*   (glitz support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_QUARTZ: The surface is of type quartz, since 1.2
* @CAIRO_SURFACE_TYPE_WIN32: The surface is of type win32, since 1.2
* @CAIRO_SURFACE_TYPE_BEOS: The surface is of type beos, since 1.2, deprecated 1.18
*   (beos support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_DIRECTFB: The surface is of type directfb, since 1.2, deprecated 1.18
*   (directfb support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_SVG: The surface is of type svg, since 1.2
* @CAIRO_SURFACE_TYPE_OS2: The surface is of type os2, since 1.4, deprecated 1.18
*   (os2 support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_WIN32_PRINTING: The surface is a win32 printing surface, since 1.6
* @CAIRO_SURFACE_TYPE_QUARTZ_IMAGE: The surface is of type quartz_image, since 1.6
* @CAIRO_SURFACE_TYPE_SCRIPT: The surface is of type script, since 1.10
* @CAIRO_SURFACE_TYPE_QT: The surface is of type Qt, since 1.10, deprecated 1.18
*   (Ot support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_RECORDING: The surface is of type recording, since 1.10
* @CAIRO_SURFACE_TYPE_VG: The surface is a OpenVG surface, since 1.10, deprecated 1.18
*   (OpenVG support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_GL: The surface is of type OpenGL, since 1.10, deprecated 1.18
*   (OpenGL support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_DRM: The surface is of type Direct Render Manager, since 1.10, deprecated 1.18
*   (DRM support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_TEE: The surface is of type 'tee' (a multiplexing surface), since 1.10
* @CAIRO_SURFACE_TYPE_XML: The surface is of type XML (for debugging), since 1.10
* @CAIRO_SURFACE_TYPE_SKIA: The surface is of type Skia, since 1.10, deprecated 1.18
*   (Skia support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_SUBSURFACE: The surface is a subsurface created with
*   cairo_surface_create_for_rectangle(), since 1.10
* @CAIRO_SURFACE_TYPE_COGL: This surface is of type Cogl, since 1.12, deprecated 1.18
*   (Cogl support have been removed, this surface type will never be set by cairo)
*
* #cairo_surface_type_t is used to describe the type of a given
* surface. The surface types are also known as "backends" or "surface
* backends" within cairo.
*
* The type of a surface is determined by the function used to create
* it, which will generally be of the form
* <function>cairo_<emphasis>type</emphasis>_surface_create(<!-- -->)</function>,
* (though see cairo_surface_create_similar() as well).
*
* The surface type can be queried with cairo_surface_get_type()
*
* The various #cairo_surface_t functions can be used with surfaces of
* any type, but some backends also provide type-specific functions
* that must only be called with a surface of the appropriate
* type. These functions have names that begin with
* <literal>cairo_<emphasis>type</emphasis>_surface</literal> such as cairo_image_surface_get_width().
*
* The behavior of calling a type-specific function with a surface of
* the wrong type is undefined.
*
* New entries may be added in future versions.
*
* Since: 1.2
**/
_cairo_surface_type :: enum u32 {
	IMAGE          = 0,
	PDF            = 1,
	PS             = 2,
	XLIB           = 3,
	XCB            = 4,
	GLITZ          = 5,
	QUARTZ         = 6,
	WIN32          = 7,
	BEOS           = 8,
	DIRECTFB       = 9,
	SVG            = 10,
	OS2            = 11,
	WIN32_PRINTING = 12,
	QUARTZ_IMAGE   = 13,
	SCRIPT         = 14,
	QT             = 15,
	RECORDING      = 16,
	VG             = 17,
	GL             = 18,
	DRM            = 19,
	TEE            = 20,
	XML            = 21,
	SKIA           = 22,
	SUBSURFACE     = 23,
	COGL           = 24,
}

/**
* cairo_surface_type_t:
* @CAIRO_SURFACE_TYPE_IMAGE: The surface is of type image, since 1.2
* @CAIRO_SURFACE_TYPE_PDF: The surface is of type pdf, since 1.2
* @CAIRO_SURFACE_TYPE_PS: The surface is of type ps, since 1.2
* @CAIRO_SURFACE_TYPE_XLIB: The surface is of type xlib, since 1.2
* @CAIRO_SURFACE_TYPE_XCB: The surface is of type xcb, since 1.2
* @CAIRO_SURFACE_TYPE_GLITZ: The surface is of type glitz, since 1.2, deprecated 1.18
*   (glitz support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_QUARTZ: The surface is of type quartz, since 1.2
* @CAIRO_SURFACE_TYPE_WIN32: The surface is of type win32, since 1.2
* @CAIRO_SURFACE_TYPE_BEOS: The surface is of type beos, since 1.2, deprecated 1.18
*   (beos support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_DIRECTFB: The surface is of type directfb, since 1.2, deprecated 1.18
*   (directfb support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_SVG: The surface is of type svg, since 1.2
* @CAIRO_SURFACE_TYPE_OS2: The surface is of type os2, since 1.4, deprecated 1.18
*   (os2 support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_WIN32_PRINTING: The surface is a win32 printing surface, since 1.6
* @CAIRO_SURFACE_TYPE_QUARTZ_IMAGE: The surface is of type quartz_image, since 1.6
* @CAIRO_SURFACE_TYPE_SCRIPT: The surface is of type script, since 1.10
* @CAIRO_SURFACE_TYPE_QT: The surface is of type Qt, since 1.10, deprecated 1.18
*   (Ot support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_RECORDING: The surface is of type recording, since 1.10
* @CAIRO_SURFACE_TYPE_VG: The surface is a OpenVG surface, since 1.10, deprecated 1.18
*   (OpenVG support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_GL: The surface is of type OpenGL, since 1.10, deprecated 1.18
*   (OpenGL support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_DRM: The surface is of type Direct Render Manager, since 1.10, deprecated 1.18
*   (DRM support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_TEE: The surface is of type 'tee' (a multiplexing surface), since 1.10
* @CAIRO_SURFACE_TYPE_XML: The surface is of type XML (for debugging), since 1.10
* @CAIRO_SURFACE_TYPE_SKIA: The surface is of type Skia, since 1.10, deprecated 1.18
*   (Skia support have been removed, this surface type will never be set by cairo)
* @CAIRO_SURFACE_TYPE_SUBSURFACE: The surface is a subsurface created with
*   cairo_surface_create_for_rectangle(), since 1.10
* @CAIRO_SURFACE_TYPE_COGL: This surface is of type Cogl, since 1.12, deprecated 1.18
*   (Cogl support have been removed, this surface type will never be set by cairo)
*
* #cairo_surface_type_t is used to describe the type of a given
* surface. The surface types are also known as "backends" or "surface
* backends" within cairo.
*
* The type of a surface is determined by the function used to create
* it, which will generally be of the form
* <function>cairo_<emphasis>type</emphasis>_surface_create(<!-- -->)</function>,
* (though see cairo_surface_create_similar() as well).
*
* The surface type can be queried with cairo_surface_get_type()
*
* The various #cairo_surface_t functions can be used with surfaces of
* any type, but some backends also provide type-specific functions
* that must only be called with a surface of the appropriate
* type. These functions have names that begin with
* <literal>cairo_<emphasis>type</emphasis>_surface</literal> such as cairo_image_surface_get_width().
*
* The behavior of calling a type-specific function with a surface of
* the wrong type is undefined.
*
* New entries may be added in future versions.
*
* Since: 1.2
**/
surface_type_t :: _cairo_surface_type

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	surface_get_type :: proc(surface: ^surface_t) -> surface_type_t ---
	surface_get_content :: proc(surface: ^surface_t) -> content_t ---
	surface_write_to_png :: proc(surface: ^surface_t, filename: cstring) -> status_t ---
	surface_write_to_png_stream :: proc(surface: ^surface_t, write_func: write_func_t, closure: rawptr) -> status_t ---
	surface_get_user_data :: proc(surface: ^surface_t, key: ^user_data_key_t) -> rawptr ---
	surface_set_user_data :: proc(surface: ^surface_t, key: ^user_data_key_t, user_data: rawptr, destroy: destroy_func_t) -> status_t ---
}

MIME_TYPE_JPEG :: "image/jpeg"
MIME_TYPE_PNG :: "image/png"
MIME_TYPE_JP2 :: "image/jp2"
MIME_TYPE_URI :: "text/x-uri"
MIME_TYPE_UNIQUE_ID :: "application/x-cairo.uuid"
MIME_TYPE_JBIG2 :: "application/x-cairo.jbig2"
MIME_TYPE_JBIG2_GLOBAL :: "application/x-cairo.jbig2-global"
MIME_TYPE_JBIG2_GLOBAL_ID :: "application/x-cairo.jbig2-global-id"
MIME_TYPE_CCITT_FAX :: "image/g3fax"
MIME_TYPE_CCITT_FAX_PARAMS :: "application/x-cairo.ccitt.params"
MIME_TYPE_EPS :: "application/postscript"
MIME_TYPE_EPS_PARAMS :: "application/x-cairo.eps.params"

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	surface_get_mime_data :: proc(surface: ^surface_t, mime_type: cstring, data: ^^u8, length: ^c.ulong) ---
	surface_set_mime_data :: proc(surface: ^surface_t, mime_type: cstring, data: ^u8, length: c.ulong, destroy: destroy_func_t, closure: rawptr) -> status_t ---
	surface_supports_mime_type :: proc(surface: ^surface_t, mime_type: cstring) -> bool_t ---
	surface_get_font_options :: proc(surface: ^surface_t, options: ^font_options_t) ---
	surface_flush :: proc(surface: ^surface_t) ---
	surface_mark_dirty :: proc(surface: ^surface_t) ---
	surface_mark_dirty_rectangle :: proc(surface: ^surface_t, x: i32, y: i32, width: i32, height: i32) ---
	surface_set_device_scale :: proc(surface: ^surface_t, x_scale: f64, y_scale: f64) ---
	surface_get_device_scale :: proc(surface: ^surface_t, x_scale: ^f64, y_scale: ^f64) ---
	surface_set_device_offset :: proc(surface: ^surface_t, x_offset: f64, y_offset: f64) ---
	surface_get_device_offset :: proc(surface: ^surface_t, x_offset: ^f64, y_offset: ^f64) ---
	surface_set_fallback_resolution :: proc(surface: ^surface_t, x_pixels_per_inch: f64, y_pixels_per_inch: f64) ---
	surface_get_fallback_resolution :: proc(surface: ^surface_t, x_pixels_per_inch: ^f64, y_pixels_per_inch: ^f64) ---
	surface_copy_page :: proc(surface: ^surface_t) ---
	surface_show_page :: proc(surface: ^surface_t) ---
	surface_has_show_text_glyphs :: proc(surface: ^surface_t) -> bool_t ---

	/* Image-surface functions */
	image_surface_create :: proc(format: format_t, width: i32, height: i32) -> ^surface_t ---
	format_stride_for_width :: proc(format: format_t, width: i32) -> i32 ---
	image_surface_create_for_data :: proc(data: ^u8, format: format_t, width: i32, height: i32, stride: i32) -> ^surface_t ---
	image_surface_get_data :: proc(surface: ^surface_t) -> [^]u8 ---
	image_surface_get_format :: proc(surface: ^surface_t) -> format_t ---
	image_surface_get_width :: proc(surface: ^surface_t) -> i32 ---
	image_surface_get_height :: proc(surface: ^surface_t) -> i32 ---
	image_surface_get_stride :: proc(surface: ^surface_t) -> i32 ---
	image_surface_create_from_png :: proc(filename: cstring) -> ^surface_t ---
	image_surface_create_from_png_stream :: proc(read_func: read_func_t, closure: rawptr) -> ^surface_t ---

	/* Recording-surface functions */
	recording_surface_create :: proc(content: content_t, extents: ^rectangle_t) -> ^surface_t ---
	recording_surface_ink_extents :: proc(surface: ^surface_t, x0: ^f64, y0: ^f64, width: ^f64, height: ^f64) ---
	recording_surface_get_extents :: proc(surface: ^surface_t, extents: ^rectangle_t) -> bool_t ---
}

/**
* cairo_raster_source_acquire_func_t:
* @pattern: the pattern being rendered from
* @callback_data: the user data supplied during creation
* @target: the rendering target surface
* @extents: rectangular region of interest in pixels in sample space
*
* #cairo_raster_source_acquire_func_t is the type of function which is
* called when a pattern is being rendered from. It should create a surface
* that provides the pixel data for the region of interest as defined by
* extents, though the surface itself does not have to be limited to that
* area. For convenience the surface should probably be of image type,
* created with cairo_surface_create_similar_image() for the target (which
* enables the number of copies to be reduced during transfer to the
* device). Another option, might be to return a similar surface to the
* target for explicit handling by the application of a set of cached sources
* on the device. The region of sample data provided should be defined using
* cairo_surface_set_device_offset() to specify the top-left corner of the
* sample data (along with width and height of the surface).
*
* Returns: a #cairo_surface_t
*
* Since: 1.12
**/
raster_source_acquire_func_t :: proc "c" (
	pattern: ^pattern_t,
	callback_data: rawptr,
	target: ^surface_t,
	extents: ^rectangle_int_t,
) -> ^surface_t

/**
* cairo_raster_source_release_func_t:
* @pattern: the pattern being rendered from
* @callback_data: the user data supplied during creation
* @surface: the surface created during acquire
*
* #cairo_raster_source_release_func_t is the type of function which is
* called when the pixel data is no longer being access by the pattern
* for the rendering operation. Typically this function will simply
* destroy the surface created during acquire.
*
* Since: 1.12
**/
raster_source_release_func_t :: proc "c" (
	pattern: ^pattern_t,
	callback_data: rawptr,
	surface: ^surface_t,
)

/**
* cairo_raster_source_snapshot_func_t:
* @pattern: the pattern being rendered from
* @callback_data: the user data supplied during creation
*
* #cairo_raster_source_snapshot_func_t is the type of function which is
* called when the pixel data needs to be preserved for later use
* during printing. This pattern will be accessed again later, and it
* is expected to provide the pixel data that was current at the time
* of snapshotting.
*
* Return value: CAIRO_STATUS_SUCCESS on success, or one of the
* #cairo_status_t error codes for failure.
*
* Since: 1.12
**/
raster_source_snapshot_func_t :: proc "c" (pattern: ^pattern_t, callback_data: rawptr) -> status_t

/**
* cairo_raster_source_copy_func_t:
* @pattern: the #cairo_pattern_t that was copied to
* @callback_data: the user data supplied during creation
* @other: the #cairo_pattern_t being used as the source for the copy
*
* #cairo_raster_source_copy_func_t is the type of function which is
* called when the pattern gets copied as a normal part of rendering.
*
* Return value: CAIRO_STATUS_SUCCESS on success, or one of the
* #cairo_status_t error codes for failure.
*
* Since: 1.12
**/
raster_source_copy_func_t :: proc "c" (
	pattern: ^pattern_t,
	callback_data: rawptr,
	other: ^pattern_t,
) -> status_t

/**
* cairo_raster_source_finish_func_t:
* @pattern: the pattern being rendered from
* @callback_data: the user data supplied during creation
*
* #cairo_raster_source_finish_func_t is the type of function which is
* called when the pattern (or a copy thereof) is no longer required.
*
* Since: 1.12
**/
raster_source_finish_func_t :: proc "c" (pattern: ^pattern_t, callback_data: rawptr)

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	pattern_create_raster_source :: proc(user_data: rawptr, content: content_t, width: i32, height: i32) -> ^pattern_t ---
	raster_source_pattern_set_callback_data :: proc(pattern: ^pattern_t, data: rawptr) ---
	raster_source_pattern_get_callback_data :: proc(pattern: ^pattern_t) -> rawptr ---
	raster_source_pattern_set_acquire :: proc(pattern: ^pattern_t, acquire: raster_source_acquire_func_t, release: raster_source_release_func_t) ---
	raster_source_pattern_get_acquire :: proc(pattern: ^pattern_t, acquire: ^raster_source_acquire_func_t, release: ^raster_source_release_func_t) ---
	raster_source_pattern_set_snapshot :: proc(pattern: ^pattern_t, snapshot: raster_source_snapshot_func_t) ---
	raster_source_pattern_get_snapshot :: proc(pattern: ^pattern_t) -> raster_source_snapshot_func_t ---
	raster_source_pattern_set_copy :: proc(pattern: ^pattern_t, copy: raster_source_copy_func_t) ---
	raster_source_pattern_get_copy :: proc(pattern: ^pattern_t) -> raster_source_copy_func_t ---
	raster_source_pattern_set_finish :: proc(pattern: ^pattern_t, finish: raster_source_finish_func_t) ---
	raster_source_pattern_get_finish :: proc(pattern: ^pattern_t) -> raster_source_finish_func_t ---

	/* Pattern creation functions */
	pattern_create_rgb :: proc(red: f64, green: f64, blue: f64) -> ^pattern_t ---
	pattern_create_rgba :: proc(red: f64, green: f64, blue: f64, alpha: f64) -> ^pattern_t ---
	pattern_create_for_surface :: proc(surface: ^surface_t) -> ^pattern_t ---
	pattern_create_linear :: proc(x0: f64, y0: f64, x1: f64, y1: f64) -> ^pattern_t ---
	pattern_create_radial :: proc(cx0: f64, cy0: f64, radius0: f64, cx1: f64, cy1: f64, radius1: f64) -> ^pattern_t ---
	pattern_create_mesh :: proc() -> ^pattern_t ---
	pattern_reference :: proc(pattern: ^pattern_t) -> ^pattern_t ---
	pattern_destroy :: proc(pattern: ^pattern_t) ---
	pattern_get_reference_count :: proc(pattern: ^pattern_t) -> u32 ---
	pattern_status :: proc(pattern: ^pattern_t) -> status_t ---
	pattern_get_user_data :: proc(pattern: ^pattern_t, key: ^user_data_key_t) -> rawptr ---
	pattern_set_user_data :: proc(pattern: ^pattern_t, key: ^user_data_key_t, user_data: rawptr, destroy: destroy_func_t) -> status_t ---
}

/**
* cairo_pattern_type_t:
* @CAIRO_PATTERN_TYPE_SOLID: The pattern is a solid (uniform)
* color. It may be opaque or translucent, since 1.2.
* @CAIRO_PATTERN_TYPE_SURFACE: The pattern is a based on a surface (an image), since 1.2.
* @CAIRO_PATTERN_TYPE_LINEAR: The pattern is a linear gradient, since 1.2.
* @CAIRO_PATTERN_TYPE_RADIAL: The pattern is a radial gradient, since 1.2.
* @CAIRO_PATTERN_TYPE_MESH: The pattern is a mesh, since 1.12.
* @CAIRO_PATTERN_TYPE_RASTER_SOURCE: The pattern is a user pattern providing raster data, since 1.12.
*
* #cairo_pattern_type_t is used to describe the type of a given pattern.
*
* The type of a pattern is determined by the function used to create
* it. The cairo_pattern_create_rgb() and cairo_pattern_create_rgba()
* functions create SOLID patterns. The remaining
* cairo_pattern_create<!-- --> functions map to pattern types in obvious
* ways.
*
* The pattern type can be queried with cairo_pattern_get_type()
*
* Most #cairo_pattern_t functions can be called with a pattern of any
* type, (though trying to change the extend or filter for a solid
* pattern will have no effect). A notable exception is
* cairo_pattern_add_color_stop_rgb() and
* cairo_pattern_add_color_stop_rgba() which must only be called with
* gradient patterns (either LINEAR or RADIAL). Otherwise the pattern
* will be shutdown and put into an error state.
*
* New entries may be added in future versions.
*
* Since: 1.2
**/
_cairo_pattern_type :: enum u32 {
	SOLID         = 0,
	SURFACE       = 1,
	LINEAR        = 2,
	RADIAL        = 3,
	MESH          = 4,
	RASTER_SOURCE = 5,
}

/**
* cairo_pattern_type_t:
* @CAIRO_PATTERN_TYPE_SOLID: The pattern is a solid (uniform)
* color. It may be opaque or translucent, since 1.2.
* @CAIRO_PATTERN_TYPE_SURFACE: The pattern is a based on a surface (an image), since 1.2.
* @CAIRO_PATTERN_TYPE_LINEAR: The pattern is a linear gradient, since 1.2.
* @CAIRO_PATTERN_TYPE_RADIAL: The pattern is a radial gradient, since 1.2.
* @CAIRO_PATTERN_TYPE_MESH: The pattern is a mesh, since 1.12.
* @CAIRO_PATTERN_TYPE_RASTER_SOURCE: The pattern is a user pattern providing raster data, since 1.12.
*
* #cairo_pattern_type_t is used to describe the type of a given pattern.
*
* The type of a pattern is determined by the function used to create
* it. The cairo_pattern_create_rgb() and cairo_pattern_create_rgba()
* functions create SOLID patterns. The remaining
* cairo_pattern_create<!-- --> functions map to pattern types in obvious
* ways.
*
* The pattern type can be queried with cairo_pattern_get_type()
*
* Most #cairo_pattern_t functions can be called with a pattern of any
* type, (though trying to change the extend or filter for a solid
* pattern will have no effect). A notable exception is
* cairo_pattern_add_color_stop_rgb() and
* cairo_pattern_add_color_stop_rgba() which must only be called with
* gradient patterns (either LINEAR or RADIAL). Otherwise the pattern
* will be shutdown and put into an error state.
*
* New entries may be added in future versions.
*
* Since: 1.2
**/
pattern_type_t :: _cairo_pattern_type

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	pattern_get_type :: proc(pattern: ^pattern_t) -> pattern_type_t ---
	pattern_add_color_stop_rgb :: proc(pattern: ^pattern_t, offset: f64, red: f64, green: f64, blue: f64) ---
	pattern_add_color_stop_rgba :: proc(pattern: ^pattern_t, offset: f64, red: f64, green: f64, blue: f64, alpha: f64) ---
	mesh_pattern_begin_patch :: proc(pattern: ^pattern_t) ---
	mesh_pattern_end_patch :: proc(pattern: ^pattern_t) ---
	mesh_pattern_curve_to :: proc(pattern: ^pattern_t, x1: f64, y1: f64, x2: f64, y2: f64, x3: f64, y3: f64) ---
	mesh_pattern_line_to :: proc(pattern: ^pattern_t, x: f64, y: f64) ---
	mesh_pattern_move_to :: proc(pattern: ^pattern_t, x: f64, y: f64) ---
	mesh_pattern_set_control_point :: proc(pattern: ^pattern_t, point_num: u32, x: f64, y: f64) ---
	mesh_pattern_set_corner_color_rgb :: proc(pattern: ^pattern_t, corner_num: u32, red: f64, green: f64, blue: f64) ---
	mesh_pattern_set_corner_color_rgba :: proc(pattern: ^pattern_t, corner_num: u32, red: f64, green: f64, blue: f64, alpha: f64) ---
	pattern_set_matrix :: proc(pattern: ^pattern_t, _matrix: ^matrix_t) ---
	pattern_get_matrix :: proc(pattern: ^pattern_t, _matrix: ^matrix_t) ---
}

/**
* cairo_extend_t:
* @CAIRO_EXTEND_NONE: pixels outside of the source pattern
*   are fully transparent (Since 1.0)
* @CAIRO_EXTEND_REPEAT: the pattern is tiled by repeating (Since 1.0)
* @CAIRO_EXTEND_REFLECT: the pattern is tiled by reflecting
*   at the edges (Since 1.0; but only implemented for surface patterns since 1.6)
* @CAIRO_EXTEND_PAD: pixels outside of the pattern copy
*   the closest pixel from the source (Since 1.2; but only
*   implemented for surface patterns since 1.6)
*
* #cairo_extend_t is used to describe how pattern color/alpha will be
* determined for areas "outside" the pattern's natural area, (for
* example, outside the surface bounds or outside the gradient
* geometry).
*
* Mesh patterns are not affected by the extend mode.
*
* The default extend mode is %CAIRO_EXTEND_NONE for surface patterns
* and %CAIRO_EXTEND_PAD for gradient patterns.
*
* New entries may be added in future versions.
*
* Since: 1.0
**/
_cairo_extend :: enum u32 {
	NONE    = 0,
	REPEAT  = 1,
	REFLECT = 2,
	PAD     = 3,
}

/**
* cairo_extend_t:
* @CAIRO_EXTEND_NONE: pixels outside of the source pattern
*   are fully transparent (Since 1.0)
* @CAIRO_EXTEND_REPEAT: the pattern is tiled by repeating (Since 1.0)
* @CAIRO_EXTEND_REFLECT: the pattern is tiled by reflecting
*   at the edges (Since 1.0; but only implemented for surface patterns since 1.6)
* @CAIRO_EXTEND_PAD: pixels outside of the pattern copy
*   the closest pixel from the source (Since 1.2; but only
*   implemented for surface patterns since 1.6)
*
* #cairo_extend_t is used to describe how pattern color/alpha will be
* determined for areas "outside" the pattern's natural area, (for
* example, outside the surface bounds or outside the gradient
* geometry).
*
* Mesh patterns are not affected by the extend mode.
*
* The default extend mode is %CAIRO_EXTEND_NONE for surface patterns
* and %CAIRO_EXTEND_PAD for gradient patterns.
*
* New entries may be added in future versions.
*
* Since: 1.0
**/
extend_t :: _cairo_extend

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	pattern_set_extend :: proc(pattern: ^pattern_t, extend: extend_t) ---
	pattern_get_extend :: proc(pattern: ^pattern_t) -> extend_t ---
}

/**
* cairo_filter_t:
* @CAIRO_FILTER_FAST: A high-performance filter, with quality similar
*     to %CAIRO_FILTER_NEAREST (Since 1.0)
* @CAIRO_FILTER_GOOD: A reasonable-performance filter, with quality
*     similar to %CAIRO_FILTER_BILINEAR (Since 1.0)
* @CAIRO_FILTER_BEST: The highest-quality available, performance may
*     not be suitable for interactive use. (Since 1.0)
* @CAIRO_FILTER_NEAREST: Nearest-neighbor filtering (Since 1.0)
* @CAIRO_FILTER_BILINEAR: Linear interpolation in two dimensions (Since 1.0)
* @CAIRO_FILTER_GAUSSIAN: This filter value is currently
*     unimplemented, and should not be used in current code. (Since 1.0)
*
* #cairo_filter_t is used to indicate what filtering should be
* applied when reading pixel values from patterns. See
* cairo_pattern_set_filter() for indicating the desired filter to be
* used with a particular pattern.
*
* Since: 1.0
**/
_cairo_filter :: enum u32 {
	FAST     = 0,
	GOOD     = 1,
	BEST     = 2,
	NEAREST  = 3,
	BILINEAR = 4,
	GAUSSIAN = 5,
}

/**
* cairo_filter_t:
* @CAIRO_FILTER_FAST: A high-performance filter, with quality similar
*     to %CAIRO_FILTER_NEAREST (Since 1.0)
* @CAIRO_FILTER_GOOD: A reasonable-performance filter, with quality
*     similar to %CAIRO_FILTER_BILINEAR (Since 1.0)
* @CAIRO_FILTER_BEST: The highest-quality available, performance may
*     not be suitable for interactive use. (Since 1.0)
* @CAIRO_FILTER_NEAREST: Nearest-neighbor filtering (Since 1.0)
* @CAIRO_FILTER_BILINEAR: Linear interpolation in two dimensions (Since 1.0)
* @CAIRO_FILTER_GAUSSIAN: This filter value is currently
*     unimplemented, and should not be used in current code. (Since 1.0)
*
* #cairo_filter_t is used to indicate what filtering should be
* applied when reading pixel values from patterns. See
* cairo_pattern_set_filter() for indicating the desired filter to be
* used with a particular pattern.
*
* Since: 1.0
**/
filter_t :: _cairo_filter

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	pattern_set_filter :: proc(pattern: ^pattern_t, filter: filter_t) ---
	pattern_get_filter :: proc(pattern: ^pattern_t) -> filter_t ---
	pattern_get_rgba :: proc(pattern: ^pattern_t, red: ^f64, green: ^f64, blue: ^f64, alpha: ^f64) -> status_t ---
	pattern_get_surface :: proc(pattern: ^pattern_t, surface: ^^surface_t) -> status_t ---
	pattern_get_color_stop_rgba :: proc(pattern: ^pattern_t, index: i32, offset: ^f64, red: ^f64, green: ^f64, blue: ^f64, alpha: ^f64) -> status_t ---
	pattern_get_color_stop_count :: proc(pattern: ^pattern_t, count: ^i32) -> status_t ---
	pattern_get_linear_points :: proc(pattern: ^pattern_t, x0: ^f64, y0: ^f64, x1: ^f64, y1: ^f64) -> status_t ---
	pattern_get_radial_circles :: proc(pattern: ^pattern_t, x0: ^f64, y0: ^f64, r0: ^f64, x1: ^f64, y1: ^f64, r1: ^f64) -> status_t ---
	mesh_pattern_get_patch_count :: proc(pattern: ^pattern_t, count: ^u32) -> status_t ---
	mesh_pattern_get_path :: proc(pattern: ^pattern_t, patch_num: u32) -> ^path_t ---
	mesh_pattern_get_corner_color_rgba :: proc(pattern: ^pattern_t, patch_num: u32, corner_num: u32, red: ^f64, green: ^f64, blue: ^f64, alpha: ^f64) -> status_t ---
	mesh_pattern_get_control_point :: proc(pattern: ^pattern_t, patch_num: u32, point_num: u32, x: ^f64, y: ^f64) -> status_t ---

	/* Matrix functions */
	matrix_init :: proc(_matrix: ^matrix_t, xx: f64, yx: f64, xy: f64, yy: f64, x0: f64, y0: f64) ---
	matrix_init_identity :: proc(_matrix: ^matrix_t) ---
	matrix_init_translate :: proc(_matrix: ^matrix_t, tx: f64, ty: f64) ---
	matrix_init_scale :: proc(_matrix: ^matrix_t, sx: f64, sy: f64) ---
	matrix_init_rotate :: proc(_matrix: ^matrix_t, radians: f64) ---
	matrix_translate :: proc(_matrix: ^matrix_t, tx: f64, ty: f64) ---
	matrix_scale :: proc(_matrix: ^matrix_t, sx: f64, sy: f64) ---
	matrix_rotate :: proc(_matrix: ^matrix_t, radians: f64) ---
	matrix_invert :: proc(_matrix: ^matrix_t) -> status_t ---
	matrix_multiply :: proc(result: ^matrix_t, a: ^matrix_t, b: ^matrix_t) ---
	matrix_transform_distance :: proc(_matrix: ^matrix_t, dx: ^f64, dy: ^f64) ---
	matrix_transform_point :: proc(_matrix: ^matrix_t, x: ^f64, y: ^f64) ---
}

/**
* cairo_region_t:
*
* A #cairo_region_t represents a set of integer-aligned rectangles.
*
* It allows set-theoretical operations like cairo_region_union() and
* cairo_region_intersect() to be performed on them.
*
* Memory management of #cairo_region_t is done with
* cairo_region_reference() and cairo_region_destroy().
*
* Since: 1.10
**/
region_t :: _cairo_region
_cairo_region :: struct {}

/**
* cairo_region_overlap_t:
* @CAIRO_REGION_OVERLAP_IN: The contents are entirely inside the region. (Since 1.10)
* @CAIRO_REGION_OVERLAP_OUT: The contents are entirely outside the region. (Since 1.10)
* @CAIRO_REGION_OVERLAP_PART: The contents are partially inside and
*     partially outside the region. (Since 1.10)
*
* Used as the return value for cairo_region_contains_rectangle().
*
* Since: 1.10
**/
_cairo_region_overlap :: enum u32 {
	IN   = 0, /* completely inside region */
	OUT  = 1, /* completely outside region */
	PART = 2, /* partly inside region */
}

/**
* cairo_region_overlap_t:
* @CAIRO_REGION_OVERLAP_IN: The contents are entirely inside the region. (Since 1.10)
* @CAIRO_REGION_OVERLAP_OUT: The contents are entirely outside the region. (Since 1.10)
* @CAIRO_REGION_OVERLAP_PART: The contents are partially inside and
*     partially outside the region. (Since 1.10)
*
* Used as the return value for cairo_region_contains_rectangle().
*
* Since: 1.10
**/
region_overlap_t :: _cairo_region_overlap

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	region_create :: proc() -> ^region_t ---
	region_create_rectangle :: proc(rectangle: ^rectangle_int_t) -> ^region_t ---
	region_create_rectangles :: proc(rects: ^rectangle_int_t, count: i32) -> ^region_t ---
	region_copy :: proc(original: ^region_t) -> ^region_t ---
	region_reference :: proc(region: ^region_t) -> ^region_t ---
	region_destroy :: proc(region: ^region_t) ---
	region_equal :: proc(a: ^region_t, b: ^region_t) -> bool_t ---
	region_status :: proc(region: ^region_t) -> status_t ---
	region_get_extents :: proc(region: ^region_t, extents: ^rectangle_int_t) ---
	region_num_rectangles :: proc(region: ^region_t) -> i32 ---
	region_get_rectangle :: proc(region: ^region_t, nth: i32, rectangle: ^rectangle_int_t) ---
	region_is_empty :: proc(region: ^region_t) -> bool_t ---
	region_contains_rectangle :: proc(region: ^region_t, rectangle: ^rectangle_int_t) -> region_overlap_t ---
	region_contains_point :: proc(region: ^region_t, x: i32, y: i32) -> bool_t ---
	region_translate :: proc(region: ^region_t, dx: i32, dy: i32) ---
	region_subtract :: proc(dst: ^region_t, other: ^region_t) -> status_t ---
	region_subtract_rectangle :: proc(dst: ^region_t, rectangle: ^rectangle_int_t) -> status_t ---
	region_intersect :: proc(dst: ^region_t, other: ^region_t) -> status_t ---
	region_intersect_rectangle :: proc(dst: ^region_t, rectangle: ^rectangle_int_t) -> status_t ---
	region_union :: proc(dst: ^region_t, other: ^region_t) -> status_t ---
	region_union_rectangle :: proc(dst: ^region_t, rectangle: ^rectangle_int_t) -> status_t ---
	region_xor :: proc(dst: ^region_t, other: ^region_t) -> status_t ---
	region_xor_rectangle :: proc(dst: ^region_t, rectangle: ^rectangle_int_t) -> status_t ---

	/* Functions to be used while debugging (not intended for use in production code) */
	debug_reset_static_data :: proc() ---
}
