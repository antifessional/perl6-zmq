
.PHONY: all clean install

all: hello libhello libbox

clean:
	rm -f *.o *.out *.so hello

install:
		cp libhello.so ../../resources/libraries
		cp libbox.so ../../resources/libraries


hello: hello.c
		gcc -Wall hello.c -o hello

hello.o: hello.c
		gcc -c -Wall -fpic hello.c

libhello: hello.o
		gcc -shared -o libhello.so hello.o

box.o: box.c
		gcc -c -Wall -fpic box.c

libbox: box.o
		gcc -shared -o libbox.so box.o



