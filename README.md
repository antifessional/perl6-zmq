# NET::ZMQ

## SYNOPSIS

    Net::ZMQ is a Perl6 binding libraru for ZeroMQ 

### Status

    This is early development

### Alternatives

    There is an an earlier project https://github.com/arnsholt/Net-ZMQ         
    I started this one primarily to learn. The older project may be more 
    stable and suitable to your needs.

### ZMQ Versions

Current development is with ZeroMQ 4.2. Unfathomably, version 4
is installed on my system as libzmq.so.5. The NativeCall calls are 
therefore tp v5.

### Design Goals

    coexistence of multiple zmq versions
    perlish calling conventions
    calling

### Structure

####  Net::ZMQ::V4::Constants

    holds all the constants from zmq.h v4. They are grouped with tags.
    The tags not loaded by default are
    :EVENT
    :DEPRECATED
    :DRAFT 	Experimental, not in stable version
    :RADIO
    :IOPLEX	multiplexing
    :SECURITY

####  Net::ZMQ::V4::LowLevel

    holds NativeCall bindings for all the functions in zmq.h
    the calls are machine generated and the only check is that
    they compile.
    ZMQ_LOW_LEVEL_FUNCTIONS_TESTED holds a list of the calls used
    in the module so far. loading  Net::ZMQ::V4::Version prints it

####  Net::ZMQ::V4::Version
    use in order to chack version compatibility
    exports
	verion()
	version-major()

####
    Net::ZMQ::Context and
    Net::ZMQ::Socket
    provide a higher level OO interface

    Context
	         .new( [throw-everything => False] )   # set to True to throw non fatal errors
	         .terminate() 			                   # manually release all resources (gc would do that)
	         .shutdown()			                     # close all sockets
	         .get-option(name)                     # get Context option
	         .set-option(name, value)	             # set Context option

	options can also be accessed through methods with the name of the option
	with/without get- and set- prefixes.
	e.g get: .get-io-threads()  .io-threads()
	    set: .set-io-threads(2) .io-threads(2)
	Net::ZMQ::ContextOptions holds the dispatch table 

    Socket
	         .new( Context, Type, [throw-everything => False])
                                              # set to True to throw non fatal errors
	         .close()					                  # (GC does that)
	         .bind( uri )
	         .connect( uri )
	         .unbind( uri )
	         .disconnect( uri )
	         .send(msg, [flags] )              # flags are combined with +
	         .receive(msg, [flags] )           # flags are combined with + 	

	         .get-option-int(name)	      		# get Socket integer options
	         .get-option-cstr(name)				    # get Socket null-terminated options
	         .get-option-buf(name) 			    	# get Socket binary data options

	         .set-option-int(name, value)			# set Socket integer options
	         .set-option-cstr(name, value)	 	# set Socket null-terminated options
	         .set-option-buf(name, value)     # set Socket binary data options

	options can also be accessed through methods with the name of the option
	with/without get- and set- prefixes.
	e.g get: .get-identity()  .identity()
	    set: .set-identity(id) .identity(id)
	Net::ZMQ::SocketOptions holds the dispatch table



```

## LICENSE

All files (unless noted otherwise) can be used, modified and redistributed
under the terms of the Artistic License Version 2. Examples (in the
documentation, in tests or distributed as separate files) can be considered
public domain.

ⓒ2017 Gabriel Ash
