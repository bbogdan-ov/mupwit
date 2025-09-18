#ifndef DYNAMIC_ARRAY_H
#define DYNAMIC_ARRAY_H

#include <raylib.h>
#include <stddef.h>
#include <stdlib.h>

#define DA_RESERVE(da, capacity) if ((capacity) >= (da)->cap) { \
	(da)->cap = (capacity) * 2; \
	(da)->items = realloc((da)->items, (da)->cap * sizeof((da)->items[0])); \
	if ((da)->items == NULL) { \
		TraceLog(LOG_ERROR, "DYNAMIC ARRAY: Out of memory! (line %d)", __LINE__); \
		exit(1); \
	} \
}

#define DA_PUSH(da, item) do { \
	DA_RESERVE((da), (da)->len + 1); \
	(da)->items[(da)->len++] = (item); \
} while (0)

#endif
