
.PHONY: all clean install

all: libp6zmq

clean:
		rm -f *.o *.out *.so

install:
		cp libp6zmq.so ../../../../resources/libraries/

buffer-helper.o: buffer-helper.c
		gcc -c -Wall -fpic buffer-helper.c

libp6zmq: buffer-helper.o
		gcc -shared -o libp6zmq.so buffer-helper.o


