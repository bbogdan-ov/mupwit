package fzf

foreign import lib "./lib/libfzf.a"

import "core:c"

case_types :: enum {
	CaseSmart = 0,
	CaseIgnore,
	CaseRespect,
}

pattern_t :: struct {}
position_t :: struct {}
slab_t :: struct {}

@(default_calling_convention = "c", link_prefix = "fzf_")
foreign lib {
	parse_pattern :: proc(case_mode: case_types, pattern: [^]u8, pat_len: c.size_t, fuzzy: bool) -> ^pattern_t ---
	free_pattern :: proc(pattern: ^pattern_t) ---

	get_score :: proc(text: [^]u8, text_len: c.size_t, pattern: ^pattern_t, slab: ^slab_t) -> i32 ---
	get_positions :: proc(text: [^]u8, text_len: c.size_t, pattern: ^pattern_t, slab: ^slab_t) -> [^]position_t ---
	free_positions :: proc(pos: [^]position_t) ---

	make_default_slab :: proc() -> ^slab_t ---
	free_slab :: proc(slab: ^slab_t) ---
}
