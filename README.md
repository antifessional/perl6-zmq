# NET::ZMQ

## SYNOPSIS

    Net::ZMQ is a Perl6 binding libraru for ZeroMQ 

### Status

    This is early development

### Alternatives

    There is an an earlier project on github:  https://github.com/arnsholt/Net-ZMQ 
    I started this one primarily to learn -- While you wait ... The older project 
    may be more stable and suitable to your needs.

### ZMQ Versions

Current development is with ZeroMQ 4.2. Unfathomably, version 4
is installed on my system as libzmq.so.5. The NativeCall calls are
therefore to v5.

### Example Code
'''
  use v6;
  use Net::ZMQ::V4::Constants;
  use Net::ZMQ::Context;
  use Net::ZMQ::Socket;
  use Net::ZMQ::Message;

  my Context $ctx .= new :throw-everything;
  my Socket $s1 .= new($ctx, :pair, :throw-everything);
  my Socket $s2 .= new($ctx, :pair, :throw-everything);

  my $endpoint = 'inproc://con';
  $s1.bind($endpoint);
  $s2.connect($endpoint);

  my $counter = 0;
  my $callme = sub ($d, $h) { say 'sending ++$counter'};

  MsgBuilder.new\
          .add('a short envelope' )\
          .add( :newline )\
          .add( :empty )\
          .add('a very long story', :max-part-size(255), :newline )\
          .add('another long chunk à la française', :divide-into(3), :newline )\
          .add( :empty )\
          .finalize\
          .send($s1, :callback( $callme ));

  my $message = $s2.receive( :slurp);
  say $message;

  $s1.unbind.close;
  $s2.disconnect.close;
'''

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
    most calls are machine generated and the only check is that
    they compile.
    ZMQ_LOW_LEVEL_FUNCTIONS_TESTED holds a list of the calls used
    in the module so far. loading  Net::ZMQ::V4::Version prints it

####  Net::ZMQ::V4::Version
    use in order to chack version compatibility
    exports
	verion()
	version-major()

####
    Net::ZMQ::Context, ::Socket, ::Message
    provide a higher level OO interface

    Context
	         .new( :throw-everything(True)  )   # set to True to throw non fatal errors
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
    Attributes
      context   - the zmq-context; must be supplied to new()
      type      - the ZMQ Socket Type constant;  must be supplied to new()
      last-error - the last zmq error reported
      throw-everything  - when true, all non-fatal errors except EAGAIN (async) throw
      async-fail-throw  - when true, EAGAIN (async) throws; when false EAGAIN returns Any
      max-send-bytes    - largest single part send in bytes
      max-recv-number   - longest charcter string representing an integer number
                          in a single, integer message part
      max-recv-bytes    - bytes threshhold for truncating receive methods

    Methods
    Methods categories - send, receive, option getters and setters, ZMQ socket wrappers, misc
    Methods that do not return a useful value return self on success and Any on failure.
    Send methods return the number of bytes sent or Any.

    Socket Wrapper Methods
        close()
        bind( endpoint  )         ;endpoint must be a string with a valid zmq endpoint
        unbind( ?endpoint )
        connect( endpoint )
        disconnect( ?endpoint )

    Send Methods
          -part sends with SNDMORE flag (incomplete)
          -split causes input to be split and sent in message parts
          -async duh!
        send( Str message, :async, :part )
        send( Int msg-code, :async, :part)
        send( buf8 message-buffer, :async, :part, :max-send-bytes)
        send(Str message, Int split-at :split! :async, :part )
        send(buf8 message-buffer, Int split-at :split! :async, :part )
        send(buf8 message-buffer, Array splits, :part, :async, :callback, :max-send-bytes)
        send(:empty!, :async, :part )

    Receive Methods
          -bin causes return type to be a byte buffer (buf8) instead of a string
          -int retrieves a single integer message
          -slurp causes all waiting parts of a message to be aseembled and returned as single object
          -truncate truncatesat a maximum byte length
          -async duh!
        receive(:truncate!, :async, :bin)
        receive(:int!, :async, :max-recv-number --> Int)
        receive(:slurp!, :async, :bin)
        receive(:async, :bin)

    Options Methods
        there are option getters and setter for every socket option
        the list of options is in SocketOptions.pm
        every option name creates four legal invocations
          -setters
            option-name(new-value)
            set-option:$name(new-value)
          -getters
            option-name()
            get-option-name()
        options can also be accessed explicitly with the ZMQ option Constant.
          - valid Type Objects are Str, buf8 and Int
            get-option(Int opt-contant, Type-Object return-type, Int size )
            set-option((Int opt-contant, new-value, Type-Object type, Int size )


    Misc Methods
        doc(-->Str) ;this

	options can also be accessed through methods with the name of the option
	with/without get:$ and set:$ prefixes.
	e.g get: .get-identity()  .identity()
	    set: .set-identity(id) .identity(id)
	Net::ZMQ::SocketOptions holds the dispatch table

    The Message class is an OO interface to the zero-copy mechanism. 
    It uses a builder to build an immutable message that can be sent (and re-sent) 
    zero-copied. See example above for useage.



```

## LICENSE

All files (unless noted otherwise) can be used, modified and redistributed
under the terms of the Artistic License Version 2. Examples (in the
documentation, in tests or distributed as separate files) can be considered
public domain.

ⓒ2017 Gabriel Ash
