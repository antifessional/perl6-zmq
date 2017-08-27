
.PHONY: all clean install

all: hello libhello

clean:
	rm -f *.o *.out *.so hello

install:
		cp libhello.so ../../resources/libraries

hello: hello.c
		gcc -Wall hello.c -o hello

hello.o: hello
		gcc -c -Wall -fpic hello.c

libhello: hello.o
		gcc -shared -o libhello.so hello.o

