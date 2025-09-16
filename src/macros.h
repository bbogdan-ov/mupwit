#ifndef MACROS_H
#define MACROS_H

#include <pthread.h>
#include <assert.h>

#define LOCK(MUTEX) assert(pthread_mutex_lock(MUTEX) == 0)
#define TRYLOCK(MUTEX) pthread_mutex_trylock(MUTEX)
#define UNLOCK(MUTEX) assert(pthread_mutex_unlock(MUTEX) == 0)

#endif
