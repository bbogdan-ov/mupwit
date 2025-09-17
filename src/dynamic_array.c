#include "./dynamic_array.h"

void *da_alloc(size_t capacity) {
	void *items = malloc(capacity);
	if (items == NULL) {
		TraceLog(LOG_ERROR, "DYNAMIC ARRAY: Out of memory! (line %d)", __LINE__);
		exit(1);
	}
	return items;
}
