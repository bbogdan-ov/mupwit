#ifndef REQUESTS_H
#define REQUESTS_H

#include <raylib.h>

#include "../../thirdparty/uthash.h"

#define REQUESTS_QUEUE_CAP 32

typedef enum ReqStatus {
	REQ_PENDING = 0,
	REQ_PROCESSING,
	REQ_READY,

	REQ_DONE,
} ReqStatus;

typedef struct Request {
	int id;
	// Owned uri string
	char *song_uri;

	bool canceled;
	ReqStatus status;
	struct {
		Image image;
		Color color;
	} data;

	UT_hash_handle hh; // to make struct hashable
} Request;

#endif
