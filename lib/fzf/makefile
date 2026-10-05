CFLAGS = -Wall -std=gnu99

all:
	mkdir -p lib
	gcc $(CFLAGS) -O3 -c fzf.c
	ar rcs lib/libfzf.a *.o
	rm *.o
