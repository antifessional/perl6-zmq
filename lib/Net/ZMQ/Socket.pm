#!/usr/bin/env perl6

unit module Net::ZMQ::Socket;
use v6;
use NativeCall;

use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::V4::Constants;

use Net::ZMQ::Error;
use Net::ZMQ::Common;
use Net::ZMQ::Context;
use Net::ZMQ::SocketOptions;


my constant MAX_RECV_NUMBER = 255;
my constant MAX_SEND_BYTES = 9000;
my constant MAX_RECV_BYTES = 9000;

class Socket does SocketOptions is export {
    has Pointer $!handle;
    has Context $.context;
    has Int   $.type;
    has ZMQError $.last-error;

    has $.throw-everything;
    has $.async-fail-throw;
    has $.max-send-bytes;
    has $.max-recv-number;
    has $.max-recv-bytes;

    submethod BUILD(:$!context
                    , :$!type
                    , :$!throw-everything
                    , :$!async-fail-throw
                    , :$!max-send-bytes
                    , :$!max-recv-number
                    , :$!max-recv-bytes
                  ) {
      $!handle = zmq_socket( $!context.ctx, $!type);
      throw-error() if ! $!handle;
      $!max-send-bytes //= MAX_SEND_BYTES;
      $!max-recv-number //= MAX_RECV_NUMBER;
      $!max-recv-bytes  //= MAX_RECV_BYTES;
    }


    multi method new(Context $context, Int $type
                        , :$throw-everything
                        , :$async-fail-throw
                        , :$max-send-bytes
                        , :$max-recv-number
                        , :$max-recv-bytes
                        )
     {
      return self.bless(:$context
                        , :$type
                        , :$throw-everything
                        , :$async-fail-throw
                        , :$max-send-bytes
                        , :$max-recv-number
                        , :$max-recv-bytes
                        );

      }
    multi method new(:$context
                      , :$type
                      , :$throw-everything
                      , :$async-fail-throw
                      , :$max-send-bytes
                      , :$max-recv-number
                      , :$max-recv-bytes
                    ) {
      return self.bless(:$context
                        , :$type
                        , :$throw-everything
                        , :$async-fail-throw
                        , :$max-send-bytes
                        , :$max-recv-number
                        , :$max-recv-bytes
                        );
    }


    method DESTROY() {
        throw-error() if zmq_close( $!handle ) == -1
                            && $.throw-everything;
    }

  method !fail(:$async, --> Bool) {
    my $doc = q:to/END/;
    a place to put failure test and decision about throwing exceptions or other failure
    mechanisms.
    It retuns True unless it throws, allowing for an if condition to chain it to the test
    to produce a fail value. as in

        return Any if  ( result == - i ) && self.fail
        to return False, chain with || !
    END
    #:

        $!last-error = get-error();
        throw-error() if $async && $!last-error == ZMQ_EAGAIN && $.async-fail-throw;
        return True   if $async && $!last-error == ZMQ_EAGAIN;
        throw-error() if $.throw-everything;
        return True;
  }


    method close() {
      return (zmq_close( $!handle ) == 0) || ! self!fail;
    }

    method bind(Str $uri) {
      return (zmq_bind($!handle, $uri) == 0) || ! self!fail;
    }

    method connect(Str $uri) {
      return (zmq_connect($!handle, $uri) == 0) || ! self!fail;
    }

    method unbind(Str $uri) {
      return (zmq_unbind($!handle, $uri) == 0) || ! self!fail;
    }

    method disconnect(Str $uri) {
      return (zmq_disconnect($!handle, $uri) == 0) || ! self!fail;
    }

## SND
    # Str
    multi method send( Str $msg, :$async, :$part ) {
      return self.send( buf8.new( | $msg.encode('ISO-8859-1' )), :$async, :$part);
    }

    # int
    multi method send( Int $msg-code, :$async, :$part) {
      return self.send("$msg-code", :$async, :$part);
    }

    #buf
    multi method send( buf8 $buf, :$async, :$part, :$max-send-bytes = $!max-send-bytes) {
      my $doc = q:to/END/;
      This is the plain vnilla send for a message or message part

      END
      #:

      die "Socket:send : Message too big" if $buf.bytes > $max-send-bytes;

      my $opts = 0;
      $opts += ZMQ_SNDMORE if $part;

      my $result = zmq_send($!handle, $buf, $buf.bytes, $opts);
      return Any if ($result == -1) && self!fail(:$async);

      say "sent $result bytes instead of { $buf.bytes() } !" if $result != $buf.bytes;
      return $result;
    }


    multi method send(Str $msg, Int $split-at = MAX_SEND_BYTES, :$split!, :$async, :$part ) {
      return self.send(buf8.new( | $msg.encode('ISO-8859-1' )), $split-at, :split, :$async, :$part );
    }


    multi method send(buf8 $buf, Int $split-at=$!max-send-bytes,
                        :$split!, :$async, :$part) {
      my $doc = q:to/END/;
      This splits a message into equal parts and sends it.

      END
      #:

      my $no-more = 0;
      $no-more = ZMQ_SNDMORE if $part;
      $no-more += ZMQ_DONTWAIT if $async;
      my $more = $no-more +| ZMQ_SNDMORE;

      my $sent = 0;
      my $size = $buf.bytes;

      loop ( my $i = 0;$i < $size; $i += $split-at) {
          my $end = ($i + $split-at, $size ).min;
          my $result = zmq_send($!handle
                                , buf8.new( | $buf[$i..$end] )
                                , $end - $i
                                , ($end == $size) ?? $no-more !! $more  );
          return Any if ($result == -1) && self!fail(:$async);
          $sent += $result;
      }
      return $sent;
    }

    multi method send(:$empty!, :$part, :$async ) {
      my $opts = 0;
      $opts += ZMQ_SNDMORE if $part;

      my $result = zmq_send($!handle, buf8, 0, $opts);
      return Any if ($result == -1) && self!fail(:$async);
      return $result;
    }


    multi method send(buf8 $buf, @splits, :$part, :$async, :$callback) {
      my $doc = q:to/END/;
      sends a collated message in defined parts with zero-copy.
      $buf  - holds all the message parts sequentially
      @splits -  holds the index where every part begins. if splits are missing,
      the last one is replicated.
      part - allows the parts as an incopmlete message
      callback - specifies a function to use with zero-copy  #ISSUE (does not)
      async - duh!

      this methods uses a hack to avoid any copying of data. The locations in the
      buffer are sent as arguments to ZMQ with the assumption that
      the buffer is an immutable byte array in continguous memory and its reported
      size is accurate. Caveat Empptor!

      The callback has to be threadsafe, and it is not, yet!   #ISSUE

      END
      #:

     die "send(): Message Part too big" if $_ > MAX_SEND_BYTES  for @splits;

      my $no-more = 0;
      $no-more = ZMQ_SNDMORE if $part;
      my $more = $no-more +| ZMQ_SNDMORE;

      my $sending = 0;
      sub callback-f($data, $hint) { say "sending now { --$sending;}" ;}

      my $size = $buf.bytes;
      my $i = 0;
      my $last-split = @splits.elems - 1;
      my $sent = 0;

      while $i < $size {
          my $end = ($i +
                      (($i >= $last-split) ?? @splits[ $last-split ]
                                            !! @splits[ $i ])
                      , $size).min;

          my zmq_msg_t $msg .= new;
          my $r = $callback
                  ?? zmq_msg_init_data_callback($msg, box_array($buf, $i), $end - $i, &callback-f)
                  !! zmq_msg_init_data($msg, box_array($buf, $i), $end - $i);
          throw-error if $r  == -1;
          say "$i -> {$end - $i} : { buf8.new( | $buf[$i..^$end]).decode('ISO-8859-1')}";

          my $result = zmq_msg_send($msg
                        , $!handle
                        , ($end == $size) ?? $no-more !! $more  );
          return Any if ($result == -1) && self!fail(:$async);
          ++$sending;
          $i = $end;
          $sent += $result;
      }
      return $sent;
    }

## RECV

   # string
    multi method receive(:$truncate!, :$async, :$bin) {
      my $doc = q:to/END/;
      this method uses the vanilla recv of zmq, which truncates messages

      END
      #:
      my $max-recv-bytes = ($truncate.WHAT === Bool) ?? $!max-recv-bytes !! $truncate;
      my int $opts = 0;
      $opts = ZMQ_DONTWAIT if $async;
      my buf8 $buf .= new( (0..^$max-recv-bytes).map( { 0;}    ));

       my int $result = zmq_recv($!handle, $buf, $max-recv-bytes, $opts);

      return Any if ($result == -1) && self!fail(:$async);

      say "message truncated : $result bytes sent 4096 received !" if $result > $max-recv-bytes;
      $result = $max-recv-bytes if $result > $max-recv-bytes;

      return $bin ?? buf8.new( $buf[0..^$result] )
                  !! buf8.new( $buf[0..^$result] ).decode('ISO-8859-1');
    }

    # int
    multi method receive(:$int!, :$async, :$max-recv-number = $!max-recv-number --> Int) {
      my $doc = q:to/END/;
      this method uses a lower truncation value for integer values. The values are transmitted
      as strings

      END
      #:

      my $r = self.receive(:truncate($max-recv-number), :$async);
      return Any if ! $r.defined;
      return +$r;
    }

    # slurp
    multi method receive(:$slurp!, :$async, :$bin) {
      my $doc = q:to/END/;
      reads and assembles a message from all the parts.

      END
      #:

      my buf8 $msgbuf .= new;
      my $i = 0;
      repeat {
        my buf8 $part  = self.receive(:bin, :$async);
        return Any if ! $part.defined;

        $msgbuf[ $i++ ] =  $part[ $_]   for 0..^$part.bytes;
      } while self.incomplete;

      return $bin ?? $msgbuf
                  !! $msgbuf.decode('ISO-8859-1');
    }

    #buf
    multi method receive(:$bin, :$async) {
      my $doc = q:to/END/;
      reads one message part without size limits.

      END
      #:

        my zmq_msg_t $msg .= new;
        my int $sz = zmq_msg_init($msg);
        my int $opts = 0;
        $opts = ZMQ_DONTWAIT if $async;


        $sz = zmq_msg_recv( $msg, $!handle, $opts);
        return Any if ($sz == -1) && self!fail( :$async);

        my $data =  zmq_msg_data( $msg );

        my buf8 $buf .= new( (0..^$sz).map( { $data[$_]; } ));

        $sz = zmq_msg_close( $msg);
        return Any if ($sz == -1) && self!fail( :$async);

        return $bin ?? $buf
                    !!  $buf.decode('ISO-8859-1');
    }

## OPTIONS

### GET
    multi method get-option(int $opt, Int, int $size) {
      my size_t $len =  $size;
      my int64 $value64 = 0;
      my int32 $value32 = 0;
      my $value;
      my $f;
      if $len == 8 {
          $value := $value64;
          $f = &zmq_getsockopt_int64;
      } elsif $len == 4 {
          $value := $value32;
          $f = &zmq_getsockopt_int32;
      } else {
          die "impossible int size! $len";
      }
      return Any if ( -1 == $f($!handle, $opt, $value, $len )) && self!fail;
      return $value;
    }

    multi method get-option(int $opt, Str, int $size ) {
       my buf8 $buf .=new( (0..$size).map( { 0;}  ));
       my size_t $len = $size + 1;

       return Any if ( -1 == zmq_getsockopt($!handle, $opt, $buf, $len )) && self!fail;
       return buf8.new( $buf[0..^--$len] ).decode('utf-8');
    }

    multi method get-option(int $opt, buf8, int $size) {
       my buf8 $buf .=new( (0..^$size).map( { 0;}  ));
       my size_t $len = $size;

       return Any if ( -1 == zmq_getsockopt($!handle, $opt, $buf, $len )) && self!fail;
       return buf8.new( $buf[0..^$len] );
    }


### SET
    multi method set-option(int $opt, Int $value, Int, int $size) {
      my size_t $len = $size;
      my $array;
      my $f;
      if $len == 8 {
        $array = CArray[int64].new();
        $f = &zmq_setsockopt_int64;
      } elsif $len == 4 {
        $array = CArray[int32].new();
        $f = &zmq_setsockopt_int32;
      } else {
        die "impossible int size! $len";
      }
      $array[0] = $value;
      return Any if (-1 == $f($!handle, $opt, $array, $len )) && self!fail;
      return True;
    }

    multi method set-option(int $opt, Str $value, Str, int $size) {
      my buf8 $buf = $value.encode('ISO-8859-1');
      my size_t $len = ($buf.bytes, $size).min;

      return Any if  -1 == zmq_setsockopt($!handle, $opt, $buf, $len ) && self!fail;
      return True;
    }

    multi method set-option(int $opt, buf8 $value, buf8, int $size) {
      my size_t $len = Int.min($value.bytes,$size);

      return Any if ( -1 == zmq_setsockopt($!handle, $opt, $value, $len )) && self!fail;
      return True;
    }


### FALLBACK
    method FALLBACK($name, |c($value = Any)) {
      my Str $set-get := $value.defined ?? 'set' !! 'get';
      my Str $method := $name.substr(0,4) eq "$set-get-"  ?? $name.substr(4) !! $name;
      my int $code = self.option( $method, 'code');

      die "Socket: unrecognized option request : { ($name, $value).perl }"
          if ! $code.defined;

      my bool $can-do = self.option( $method, $set-get );

      die   "Context: {$value.value ?? 'set' !! 'get'}ting this option not allowed: { ($name, $value).perl }"
          if ! $can-do;

      my $type = self.option( $method, 'type');
      #$type = Int if $type === Any;
      my int $size = 	self.option( $method, 'size');# // 4;

      return $value // -1 if $code == ZMQ_TEST;

      return $value.defined ?? self.set-option($code, $value, $type, $size)
              !! self.get-option($code, $type, $size);
    }
}
