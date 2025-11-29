#ifndef REQUEST_H
#define REQUEST_H

#include <raylib.h>

#include "../../thirdparty/uthash.h"

#define REQUESTS_QUEUE_CAP 32

typedef struct Request {
	int id;
	// Owned uri string
	char *song_uri;
	bool canceled;
	UT_hash_handle hh; // to make struct hashable
} Request;

#endif
