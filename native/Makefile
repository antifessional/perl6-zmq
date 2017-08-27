

.PHONY pre: zmq.h zmq.e zmq.def zmq.gptrixie

.PHONY clean: rm -f zmq.h zmq.e zmq.def zmq.gptrixie plop.xml

zmq.h:
	rm -f zmq.h
	cp /usr/include/zmq.h .

zmq.e: zmq.h
	rm -f zmq.e
	gcc -E zmq.h > zmq.e

zmq.def: zmq.h
	rm -f zmq.def
	grep "^#define " zmq.h > zmq.def

zmq.gptrixie: 
	rm -f zmq.gptrixie
	gptrixie -all --castxml=c99 zmq.h > zmq.gptrixie

