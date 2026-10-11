CFLAGS = -Wall -ggdb

all:
	mkdir -p lib
	gcc $(CFLAGS) -fPIC -O3 -c wayclient/*.c
	gcc $(CFLAGS) -fPIC -O3 `pkg-config --cflags freetype2` -Iwayclient/ -c *.c
	ar rcs lib/libmywindow.a *.o
	rm *.o
