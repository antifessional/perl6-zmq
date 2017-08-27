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

class Socket does SocketOptions is export {
    has Pointer $!handle;
    has Context $.context;
    has Int   $.type;
    has Bool $.throw-everything;
    has ZMQError $.last-error;
    has int $.max-message-size;			# max size receive buffer. 

    submethod BUILD(:$!context
		    , :$!type
		    , :$!max-message-size = 1024
		    , :$!throw-everything = False
		) {
      $!handle = zmq_socket( $!context.ctx, $!type);
      throw-error() if ! $!handle;
    }

    multi method new(:$context
		    , :$type
		    ,  :$max-message-size = 1024
		    , :$throw-everything = False
		) {
      return self.bless(:$context, :$type, :$max-message-size, :$throw-everything);
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

    multi method send( buf8 $buf, Int $flags = 0) {
      my $result = zmq_send($!handle, $buf, $buf.bytes, $flags);

      if $result == -1 {
        $!last-error = $.throw-everything ?? throw-error() !! get-error();
      }

      say "sent $result bytes instead of { $buf.bytes() } !" if $result != $buf.bytes;
      return $result;
    }

    multi method send( Int $msg-code, Int $flags = 0) {
	return self.send( "$msg-code", $flags);
    }

    multi method send( Str $msg, Int $flags = 0) {
	return self.send( buf8.new( | $msg.encode('ISO-8859-1' )), $flags);
    }


## RECV

    method receive-raw(Int $flags = 0, Int $size = $.max-message-size  --> buf8) {
      state buf8 $buf .= new( (0..^$size).map( { 0;}    ));

      my int $result = zmq_recv($!handle, $buf, $size, $flags);
      if $result == -1 {
        $!last-error = $.throw-everything ?? throw-error() !! get-error();
      }
      say "message truncated : $result bytes sent 4096 received !" if $result > $size;
      $result = $size if $result > $size;	
      return buf8.new( $buf[0..^$result] );
    }

    multi method receive(Int $flags = 0, Int $size = $.max-message-size, :$bin!  --> buf8) {
	return self.receive-raw($flags, $size);
    }

    multi method receive(Int $flags = 0, Int $size = $.max-message-size  --> Str) {
	return self.receive-raw($flags, $size).decode('ISO-8859-1');
    }

    multi method receive(int $flags = 0, :$int! --> Int) {
	return +self.receive($flags); 
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

