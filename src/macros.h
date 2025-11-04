#ifndef MACROS_H
#define MACROS_H

#define __USE_UNIX98 1

#include <raylib.h>
#include <pthread.h>
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>

#define DA_INIT_CAP 32

#define TODO(MSG) do { \
	TraceLog(LOG_ERROR, "[TODO] "MSG); \
	abort(); \
} while (0)

#define LOCK(MUTEX)    assert(pthread_mutex_lock(MUTEX) == 0)
#define TRYLOCK(MUTEX) pthread_mutex_trylock(MUTEX)
#define UNLOCK(MUTEX)  assert(pthread_mutex_unlock(MUTEX) == 0)

#define READ_LOCK(RWLOCK)     assert(pthread_rwlock_rdlock(RWLOCK) == 0)
#define WRITE_LOCK(RWLOCK)    assert(pthread_rwlock_wrlock(RWLOCK) == 0)
#define READ_TRYLOCK(RWLOCK)  pthread_rwlock_tryrdlock(RWLOCK)
#define WRITE_TRYLOCK(RWLOCK) pthread_rwlock_trywrlock(RWLOCK)
#define RW_UNLOCK(RWLOCK)     assert(pthread_rwlock_unlock(RWLOCK) == 0)

#define MAX(A, B) (A < B ? B : A)
#define MIN(A, B) (A > B ? B : A)
#define CLAMP(VALUE, MN, MX) (MIN(MAX(VALUE, MN), MX))

#define SLEEP_MS(MILLIS) do { \
	struct timespec ts; \
	ts.tv_sec = (MILLIS) / 1000; \
	ts.tv_nsec = ((MILLIS) % 1000) * 1000000; \
\
	assert(nanosleep(&ts, &ts) == 0); \
} while (0)

#define DA_RESERVE(da, capacity) if ((capacity) >= (da)->cap) { \
	(da)->cap = MAX((capacity) * 2, DA_INIT_CAP); \
	(da)->items = realloc((da)->items, (da)->cap * sizeof((da)->items[0])); \
	if ((da)->items == NULL) { \
		TraceLog(LOG_ERROR, "DYNAMIC ARRAY: Out of memory! (at %s:%d)", __FILE__, __LINE__); \
		abort(); \
	} \
}

#define DA_PUSH(da, item) do { \
	DA_RESERVE((da), (da)->len + 1); \
	(da)->items[(da)->len++] = (item); \
} while (0)

#define RINGBUF_IS_EMPTY(rb) ((rb)->head == (rb)->tail)
#define RINGBUF_IS_FULL(rb)  (((rb)->head + 1) % (rb)->cap == (rb)->tail)
#define RINGBUF_LEN(rb)      ((rb)->head >= (rb)->tail \
		? (rb)->head - (rb)->tail \
		: (rb)->cap - ((rb)->tail - (rb)->head))

#define RINGBUF_PUSH(rb, item) do { \
	assert((rb)->cap > 0); \
	if (!RINGBUF_IS_FULL((rb))) { \
		(rb)->buffer[(rb)->head] = (item); \
		(rb)->head = ((rb)->head + 1) % (rb)->cap; \
	} \
} while (0)

#define RINGBUF_POP(rb, item, default) do { \
	assert((rb)->cap > 0); \
	if (!RINGBUF_IS_EMPTY((rb))) {\
		/* Acquire and reset item */ \
		*(item) = (rb)->buffer[(rb)->tail]; \
		(rb)->buffer[(rb)->tail] = (default); \
\
		(rb)->tail = ((rb)->tail + 1) % (rb)->cap; \
	} \
} while (0)

#define RINGBUF_PEEK(rb, item, default) do { \
	assert((rb)->cap > 0); \
	if (!RINGBUF_IS_EMPTY((rb))) {\
		*(item) = (rb)->buffer[(rb)->tail]; \
	} \
} while (0)

#endif
