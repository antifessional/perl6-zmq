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

class Socket does SocketOptions is export {
    has Pointer $!handle;
    has Context $.context;
    has Int   $.type;
    has Bool $.throw-everything;
    has ZMQError $.last-error;

    submethod BUILD(:$!context
                    , :$!type
                    , :$!throw-everything = False
                  ) {
      $!handle = zmq_socket( $!context.ctx, $!type);
      throw-error() if ! $!handle;
    }

    multi method new(:$context
                      , :$type
                      , :$throw-everything = False
                    ) {
      return self.bless(:$context
                        , :$type
                        , :$throw-everything);
    }


    multi method new(Context $context, Int $type,  Bool  $throw-everything = False) {
      return self.bless(:$context, :$type, :$throw-everything);
    }

    method DESTROY() {
        throw-error() if zmq_close( $!handle ) == -1
                            && $.throw-everything;
    }

    method close() {
      my $result := zmq_close( $!handle );
      if $result != 0 {
          $!last-error = $.throw-everything ?? throw-error() !! get-error();
      }
      return $result == 0;
    }

    method bind(Str $uri) {
      my $result = zmq_bind($!handle, $uri);
      if $result != 0 {
        $!last-error = $.throw-everything ?? throw-error() !! get-error();
      }
      return $result == 0;
    }

    method connect(Str $uri) {
      my $result := zmq_connect($!handle, $uri);
      if $result != 0 {
        $!last-error = $.throw-everything ?? throw-error() !! get-error();
      }
      return $result == 0;
    }

    method unbind(Str $uri) {
      my $result = zmq_unbind($!handle, $uri);
      if $result != 0 {
        $!last-error = $.throw-everything ?? throw-error() !! get-error();
      }
      return $result == 0;
    }

    method disconnect(Str $uri) {
      my $result := zmq_disconnect($!handle, $uri);
      if $result != 0 {
        $!last-error = $.throw-everything ?? throw-error() !! get-error();
      }
      return $result == 0;
    }

## SND

    method !send-raw( buf8 $buf, Int $flags = 0) {
      my $result = zmq_send($!handle, $buf, $buf.bytes, $flags);

      if $result == -1 {
        $!last-error = $.throw-everything ?? throw-error() !! get-error();
      }

      say "sent $result bytes instead of { $buf.bytes() } !" if $result != $buf.bytes;
      return $result;
    }


    method send-split( buf8 $buf, Int $flags = 0, Int $split-at = MAX_SEND_BYTES ) {
      die "Socket:send : Message too big" if $split-at > MAX_SEND_BYTES;

      my $size = $buf.bytes;
      my $more = $flags +| ZMQ_SNDMORE;say $more;
      my $no-more = $flags;
      my $sent = 0;
      loop ( my int $i = 0;$i < $size; $i += $split-at) {
          my $end = ($i + $split-at, $size ).min;
          my int $count = $end - $i;
          my buf8 $part .= new( | $buf[$i..$end] );
          my $flag = ($end == $size) ?? $no-more !! $more;
          my $result = zmq_send($!handle
                                , $part
                                , $count
                                , $flag);
          if $result == -1 {
            $!last-error = $.throw-everything ?? throw-error() !! get-error();
          }
          $sent += $result;
      }
      return $sent;
    }

    #buf
    multi method send( buf8 $buf, Int $flags = 0 ) {

      die "Socket:send : Message too big" if $buf.bytes > MAX_SEND_BYTES;

      my $result = zmq_send($!handle, $buf, $buf.bytes, $flags);

      if $result == -1 {
        $!last-error = $.throw-everything ?? throw-error() !! get-error();
      }

      say "sent $result bytes instead of { $buf.bytes() } !" if $result != $buf.bytes;
      return $result;
    }

    # Str
    multi method send( Str $msg, Int $flags = 0) {
      return self.send( buf8.new( | $msg.encode('ISO-8859-1' )), $flags);
    }

    # int
    multi method send( Int $msg-code, Int $flags = 0) {
      return self.send( "$msg-code", $flags);
    }


## RECV

    method !receive-raw(Int $flags = 0  --> buf8) {
        my zmq_msg_t $msg .= new;
        my int $sz = zmq_msg_init($msg);
#        say $msg.perl, $msg._.perl, $msg._.gist , ": $sz  :", $msg._;

        $sz = zmq_msg_recv( $msg, $!handle, $flags);
        if $sz == -1 {
          $!last-error = $.throw-everything ?? throw-error() !! get-error();
        }

        my $data :=  zmq_msg_data( $msg );
        if ! $data.defined {
          $!last-error = $.throw-everything ?? throw-error() !! get-error();
        }

        my buf8 $buf .= new( (0..^$sz).map( { $data[$_]; } ));

        $sz = zmq_msg_close( $msg);
        if $sz == -1  {
          $!last-error = $.throw-everything ?? throw-error() !! get-error();
        }

        return $buf;
    }

    method receive-upto( Int $size, Int $flags = 0  --> buf8) {
      state buf8 $buf .= new( (0..^$size).map( { 0;}    ));

      my int $result = zmq_recv($!handle, $buf, $size, $flags);
      if $result == -1 {
        $!last-error = $.throw-everything ?? throw-error() !! get-error();
      }
      say "message truncated : $result bytes sent 4096 received !" if $result > $size;
      $result = $size if $result > $size;	
      return buf8.new( $buf[0..^$result] );
    }

    # buf
    multi method receive(Int $flags = 0, :$bin!  --> buf8) {
      return self!receive-raw($flags);
    }

    # string
    multi method receive(Int $flags = 0  --> Str) {
      return self!receive-raw($flags).decode('ISO-8859-1');
    }
    
    # int
    multi method receive(int $flags = 0, :$int! --> Int) {
      return +self.receive-upto(MAX_RECV_NUMBER, $flags).decode('ISO-8859-1'); 
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

        if -1 == $f($!handle, $opt, $value, $len ) {
    	    $!last-error = $.throw-everything ?? throw-error() !! get-error();
        }
	return $value;
    }


    multi method get-option(int $opt, Str, int $size ) {
       my buf8 $buf .=new( (0..$size).map( { 0;}  ));
       my size_t $len = $size + 1;

       if -1 == zmq_getsockopt($!handle, $opt, $buf, $len ) {
    	    $!last-error = $.throw-everything ?? throw-error() !! get-error();	
	}

       return buf8.new( $buf[0..^--$len] ).decode('utf-8');
    }

    multi method get-option(int $opt, buf8, int $size) {
       my buf8 $buf .=new( (0..^$size).map( { 0;}  ));
       my size_t $len = $size;

      if -1 == zmq_getsockopt($!handle, $opt, $buf, $len ) {
        $!last-error = $.throw-everything ?? throw-error() !! get-error();	
      }

       return buf8.new( $buf[0..^$len] );
    }


### SET
use Local::Test;

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

        if -1 == $f($!handle, $opt, $array, $len ) {
    	    $!last-error = $.throw-everything ?? throw-error() !! get-error();
	    return -1;
        }
         return 0;
    }
    
    multi method set-option(int $opt, Str $value, Str, int $size) {
	my buf8 $buf = $value.encode('ISO-8859-1');
	my size_t $len = ($buf.bytes, $size).min;
	
	if -1 == zmq_setsockopt($!handle, $opt, $buf, $len ) {
	    $!last-error = $.throw-everything ?? throw-error() !! get-error();
	    return -1;
        }
        return 0;
	
    }

    multi method set-option(int $opt, buf8 $value, buf8, int $size) {
	my size_t $len = Int.min($value.bytes,$size);
	
	 if -1 == zmq_setsockopt($!handle, $opt, $value, $len ) {
	    $!last-error = $.throw-everything ?? throw-error() !! get-error();
	    return -1;
         }
         return 0;
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

#      say "FALLBACK: { ($method, self.option( $method, 'type'),  $code, $type, $size).perl }  ";
      return $value // -1 if $code == ZMQ_TEST;

      return $value.defined ?? self.set-option($code, $value, $type, $size) 
              !! self.get-option($code, $type, $size);
    }
}

