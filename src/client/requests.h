#ifndef REQUESTS_H
#define REQUESTS_H

#include <raylib.h>

#include "../../thirdparty/uthash.h"

#define REQUESTS_QUEUE_CAP 32

typedef enum RespStatus {
	RESP_PENDING = 0,
	RESP_READY,
	RESP_DONE,
} RespStatus;

typedef struct Request {
	int id;
	// Owned uri string
	char *song_uri;
	bool canceled;
	UT_hash_handle hh; // to make struct hashable
} Request;

typedef struct Response {
	int id;

	bool canceled;
	RespStatus status;
	struct {
		Image image;
		Color color;
	} data;

	UT_hash_handle hh; // to make struct hashable
} Response;

#endif
