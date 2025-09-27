#ifndef MACROS_H
#define MACROS_H

#include <pthread.h>
#include <assert.h>
#include <stdlib.h>

#define DA_INIT_CAP 32

#define MAX(A, B) (A < B ? B : A)
#define MIN(A, B) (A > B ? B : A)
#define CLAMP(VALUE, MN, MX) (MIN(MAX(VALUE, MN), MX))

#define LOCK(MUTEX) assert(pthread_mutex_lock(MUTEX) == 0)
#define TRYLOCK(MUTEX) pthread_mutex_trylock(MUTEX)
#define UNLOCK(MUTEX) assert(pthread_mutex_unlock(MUTEX) == 0)

#define DA_RESERVE(da, capacity) if ((capacity) >= (da)->cap) { \
	(da)->cap = MAX((capacity) * 2, DA_INIT_CAP); \
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
