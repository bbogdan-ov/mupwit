#ifndef RESTORE_H
#define RESTORE_H

// Try to restore previous window
// Returns `true` on success, `false` otherwise
bool try_restore(void);

bool should_skip_drawing(void);

// Returns whether the event loop should be interrupted
bool should_close(void);

#endif
