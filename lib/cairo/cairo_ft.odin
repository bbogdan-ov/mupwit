/* cairo - a vector graphics library with display and print output
 *
 * Copyright © 2005 Red Hat, Inc
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
 * The Initial Developer of the Original Code is Red Hat, Inc.
 *
 * Contributor(s):
 *      Graydon Hoare <graydon@redhat.com>
 *	Owen Taylor <otaylor@redhat.com>
 */
package cairo

@(require) foreign import lib "system:cairo"

Font_Library :: ^struct{}
Font_Face :: ^struct{}

FcPattern :: struct {}

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	ft_font_face_create_for_ft_face :: proc(face: Font_Face, load_flags: i32) -> ^font_face_t ---
}

/**
* cairo_ft_synthesize_t:
* @CAIRO_FT_SYNTHESIZE_BOLD: Embolden the glyphs (redraw with a pixel offset)
* @CAIRO_FT_SYNTHESIZE_OBLIQUE: Slant the glyph outline by 12 degrees to the
* right.
*
* A set of synthesis options to control how FreeType renders the glyphs
* for a particular font face.
*
* Individual synthesis features of a #cairo_ft_font_face_t can be set
* using cairo_ft_font_face_set_synthesize(), or disabled using
* cairo_ft_font_face_unset_synthesize(). The currently enabled set of
* synthesis options can be queried with cairo_ft_font_face_get_synthesize().
*
* Note: that when synthesizing glyphs, the font metrics returned will only
* be estimates.
*
* Since: 1.12
**/
ft_synthesize_t :: enum u32 {
	BOLD    = 1,
	OBLIQUE = 2,
}

@(default_calling_convention = "c", link_prefix = "cairo_")
foreign lib {
	ft_font_face_set_synthesize :: proc(font_face: ^font_face_t, synth_flags: u32) ---
	ft_font_face_unset_synthesize :: proc(font_face: ^font_face_t, synth_flags: u32) ---
	ft_font_face_get_synthesize :: proc(font_face: ^font_face_t) -> u32 ---
	ft_scaled_font_lock_face :: proc(scaled_font: ^scaled_font_t) -> i32 ---
	ft_scaled_font_unlock_face :: proc(scaled_font: ^scaled_font_t) ---
	ft_font_face_create_for_pattern :: proc(pattern: ^FcPattern) -> ^font_face_t ---
	ft_font_options_substitute :: proc(options: ^font_options_t, pattern: ^FcPattern) ---
}
