
.PHONY: all clean install

all: hello libhello libp6zmq

clean:
		rm -f *.o *.out *.so hello

install:
		cp libhello.so ../../resources/libraries
		cp libp6zmq.so ../../resources/libraries

hello: hello.c
		gcc -Wall hello.c -o hello

hello.o: hello.c
		gcc -c -Wall -fpic hello.c

libhello: hello.o
		gcc -shared -o libhello.so hello.o

buffer-helper.o: buffer-helper.c
		gcc -c -Wall -fpic buffer-helper.c

libp6zmq: buffer-helper.o
		gcc -shared -o libp6zmq.so buffer-helper.o



