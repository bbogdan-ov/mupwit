#include "./utils.h"
#include "./macros.h"

Color image_average_color(Image image) {
	int comps = 0;
	if (image.format == PIXELFORMAT_UNCOMPRESSED_R8G8B8)
		comps = 3;
	else if (image.format == PIXELFORMAT_UNCOMPRESSED_R8G8B8A8)
		comps = 4;

	// Calculate average color of the artwork
	Color color = {0};
	if (comps > 0) {
		unsigned char *data = image.data;
		float cr = 0.0, cg = 0.0, cb = 0.0;
		float n = 1.0;
		for (int i = 0; i < image.width * image.height * comps; i += comps) {
			int r = data[i + 0];
			int g = data[i + 1];
			int b = data[i + 2];
			float max = (float)MAX(r, MAX(g, b));
			float min = (float)MIN(r, MIN(g, b));
			float saturation = 0.0;
			float lightness = (max + min) / 2.0 / 255.0;
			if (max > 0) saturation = (max - min) / max;

			if (saturation >= 0.5 && lightness > 0.3) {
				n += 1.0;
				cr += r;
				cg += g;
				cb += b;
			}
			if (lightness >= 0.6) {
				n += 0.2;
				cr += r/5;
				cg += g/5;
				cb += b/5;
			}
		}

		color = (Color){
			(char)MAX(cr/n, 50.0),
			(char)MAX(cg/n, 50.0),
			(char)MAX(cb/n, 50.0),
			255
		};
	}

	return ColorBrightness(color, 0.4);
}
