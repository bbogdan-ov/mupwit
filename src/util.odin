package mupwit

import "base:intrinsics"
import "core:sync"
import "lib:ui"

// ------------------------------
// Sync.
// ------------------------------

Mutex :: struct($T: typeid) {
	_v:     T,
	_mutex: sync.Mutex,
}

@(deferred_in = mutex_unlock)
mutex_guard :: proc(mutex: ^Mutex($T)) -> ^T {
	return mutex_lock(mutex)
}
mutex_lock :: proc(mutex: ^Mutex($T)) -> ^T {
	sync.lock(&mutex._mutex)
	return &mutex._v
}
mutex_unlock :: proc(mutex: ^Mutex($T)) {
	sync.unlock(&mutex._mutex)
}

// ------------------------------
// Values.
// ------------------------------

enum_rotate_variant :: proc(v: $T, diff: int) -> T where intrinsics.type_is_enum(T) {
	v := int(v) + diff
	return T(ui.wrap(v, len(T)))
}
