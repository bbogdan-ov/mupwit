#ifndef UTILS_H
#define UTILS_H

#include <raylib.h>

// Get basename of the path (part after the last '/')
const char *path_basename(const char *path);

Color image_average_color(Image image);

#endif
