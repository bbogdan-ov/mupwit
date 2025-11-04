#ifndef CONTEXT_H
#define CONTEXT_H

#include "./state.h"
#include "./client.h"
#include "./assets.h"

// Struct that just combines all the commonly used structs into one place
// All these structs a guaranteed to live as long as program is running
typedef struct Context {
	State *state;
	Client *client;
	Assets *assets;
} Context;

#endif
