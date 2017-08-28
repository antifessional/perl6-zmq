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
    has Bool $.throw-async-fail;
    has ZMQError $.last-error;

    submethod BUILD(:$!context
                    , :$!type
                    , :$!throw-everything = False
                    , :$!throw-async-fail = False
                  ) {
      $!handle = zmq_socket( $!context.ctx, $!type);
      throw-error() if ! $!handle;
    }

    multi method new(:$context
                      , :$type
                      , :$throw-everything = False
                      , :$throw-async-fail = False
                    ) {
      return self.bless(:$context
                        , :$type
                        , :$throw-everything
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

    # Str
    multi method send( Str $msg, :$async, :$part ) {
      return self.send( buf8.new( | $msg.encode('ISO-8859-1' )), :$async, :$part);
    }

    # int
    multi method send( Int $msg-code, :$async, :$part) {
      return self.send("$msg-code", :$async, :$part);
    }

    #buf
    multi method send( buf8 $buf, :$async, :$part) {
      die "Socket:send : Message too big" if $buf.bytes > MAX_SEND_BYTES;
      my $opts = 0;
      $opts += ZMQ_SNDMORE if $part;  

      my $result = zmq_send($!handle, $buf, $buf.bytes, $opts);

      if $result == -1 {
        $!last-error = get-error();
        return Any if $async && $!last-error == ZMQ_EAGAIN;
        throw-error() if $.throw-everything;
      } 

      say "sent $result bytes instead of { $buf.bytes() } !" if $result != $buf.bytes;
      return $result;
    }


    multi method send(Str $msg, Int $split-at = MAX_SEND_BYTES, :$split!, :$async, :$part ) {
      return self.send(buf8.new( | $msg.encode('ISO-8859-1' )), $split-at, :split, :$async, :$part );
    }

    multi method send(buf8 $buf, Int $split-at = MAX_SEND_BYTES, :$split!, :$async, :$part) {
      die "Socket:send : Message too big" if $split-at > MAX_SEND_BYTES;

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
          if $result == -1 {
            $!last-error = get-error();
            last if $async && $!last-error == ZMQ_EAGAIN;
            throw-error() if $.throw-everything;
          }
          $sent += $result;
      }
      return $sent;
    }




## RECV

   # string, with limited size
    multi method receive(Int $size, :$async, :$bin) {
      my int $opts = 0;
      $opts = ZMQ_DONTWAIT if $async;
      my buf8 $buf .= new( (0..^$size).map( { 0;}    ));
#      my buf8 $buf .= new();
      my int $result = zmq_recv($!handle, $buf, $size, $opts);

      if $result == -1 && ! $async {
        $!last-error = $.throw-everything ?? throw-error() !! get-error();
      } elsif $result == -1 {
        return Any;
      }

      say "message truncated : $result bytes sent 4096 received !" if $result > $size;
      $result = $size if $result > $size;	

      return $bin ?? buf8.new( $buf[0..^$result] )
                  !! buf8.new( $buf[0..^$result] ).decode('ISO-8859-1');
    }

    
    # int
    multi method receive(:$int!, :$async, :$bin --> Int) {
      my $r = self.receive(MAX_RECV_NUMBER, :$async, :$bin);
      return Any if $async && ! $r.defined;
      return +$r;
    }
    
    multi method receive(:$slurp!, :$async, :$bin) {
      my buf8 $msgbuf .= new;
      my $i = 0;
      repeat {
        my buf8 $part  = self.receive(:bin, :$async);
        return Any if $async && ! $part.defined;
        $msgbuf[ $i++ ] =  $part[ $_]   for 0..^$part.bytes;
      } while self.incomplete;

      return $bin ?? $msgbuf
                  !! $msgbuf.decode('ISO-8859-1');
    }

    #buf
    multi method receive(:$bin, :$async) {
        my zmq_msg_t $msg .= new;
        my int $sz = zmq_msg_init($msg);
        my int $opts = 0;
        $opts = ZMQ_DONTWAIT if $async;

#        say $msg.perl, $msg._.perl, $msg._.gist , ": $sz  :", $msg._;

        $sz = zmq_msg_recv( $msg, $!handle, $opts);
        if $sz == -1 && ! $async {
          $!last-error = $.throw-everything ?? throw-error() !! get-error();
        } elsif $sz == -1 {
          return Any;
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

