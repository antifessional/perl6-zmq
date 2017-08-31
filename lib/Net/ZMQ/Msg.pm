#!/usr/bin/env perl6

unit module Net::ZMQ::Msg;
use v6;
use NativeCall;

use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::V4::Constants;

use Net::ZMQ::Error;
use Net::ZMQ::Common;
use Net::ZMQ::Socket;

class MsgIterator {...}
class MsgBuilder {...}

class Buffer {
  my $doc = q:to/END/;

    class Buffer wraps a byte buffer (buf8)
    ready for use for sending complex multi-part messages fast.
    It is created inside MsgBuilder and consumed by Socket
    and is not designed for end-usage.

    Attributes
      encoding   # not implemented yet

    Methods
      offset(Int segment --> Int)  - returns the position after the end of the segment
      iterator( --> MsgIterator)  - return a segment Iterator
      offset-pointer(Int i --> Pointer) - returns a Pointer to the buffer's byte i location in memory

  END
  #:

  has buf8 $.buffer     is rw;
  has uint @.offsets    is rw;
  has Int  $.next-i     is rw;

  method iterator( --> MsgIterator) {
    return MsgIterator.new(self);
  }
  method bytes() { return $!buffer.bytes; }
  method segments() { return @!offsets.elems; }
  method offset(Int $i --> Int)  {
      die "Msg: illegal offset" if $i >= @!offsets.elems;
      return @!offsets[$i];
  }
  method offset-pointer(Int $i --> Pointer )  {
      die "Msg: buffer overflow" if $i >= $!next-i;
       ## c hack here ##
       return buf8-offset($!buffer, $i);
  }
}

class MsgIterator {
  has Buffer $!buffer;
  has Int $!i;
  has Int $!offset;
  has Int $!segments;
  my $doc = q:to/END/;

    Forward Iterator over the Msg class, returns a series of segments sizes in
    bytes. example

      my $it = $buffer.iterator;
      my $from = 0;
      while $it->has-next {
        $next = $it.next;
        say "segment is from offset $from to { $next - 1 }";
        $from = $next;
      }

  END
  #:

  method TWEAK {
    die "MsgIterator needs an instance" unless $!buffer.defined;
    $!i = 0;
    $!offset = Int;
    $!segments := $!buffer.segments;
  }

  submethod BUILD( :$buffer ) { $!buffer := $buffer; }

  method new(Buffer $buffer) {
    return self.bless( :$buffer );
  }

  method next( --> Int  ) {
      die "illegal offset" if $!offset > $!buffer.bytes;
      return $!offset;
  }

  method has-next( --> Bool)  {
    return False if $!i == $!segments;
    $!offset = $!buffer.offset( $!i++ );
    die "asserting offset not in overflow" unless ($!offset <= $!buffer.bytes);
    return True;
  }
}

class Msg is export  {
  trusts MsgBuilder;
  my $doc = q:to/END/;

    class Msg is an immutable holder of a message
    ready for use in sending multi-part messages using zero-copy.
    It is created by a MsgBuilder.

    Attributes
      encoding   # not implemented yet
      encoding  # not yet implemented

    Methods
          offset(Int segment --> Int)  - returns the position after the end of the segment
          iterator( --> MsgIterator)  - return a segment Iterator
          offset-pointer(Int i --> Pointer) - returns a Pointer to the buffer's byte i location in memory
          bytes( --> Int)
          segments( --> Int)
        send(Socket, -part, -async, -callback)
        copy( --> Str)
        bytes()
        segments()

  END
  #:

  has Str $.encoding;   # not implemented yet

  has Buffer $!_;

  submethod BUILD(:$_ ) { $!_ = $_; }
  method TWEAK {  }

  method new() { die "Msg: private constructor" };

  method !create( Buffer $built) {
    return self.bless( :_($built) );
  }


  method send(Socket $socket, :$part, :$async, :$callback ) {
    my $doc = q:to/END/;
    sends the collated message in defined parts with zero-copy.
    part - allows the parts as an incopmlete message
    callback - specifies a function to use with zero-copy  #ISSUE (does not)
    async - duh!

    this methods uses a c hack to avoid any copying of data in order to benefit from
    the optimizations that rely on the use of zero-copy. The locations in the
    buffer are sent as arguments to ZMQ with the assumption that
    the buffer is an immutable byte array in continguous memory and its reported
    size is accurate. Caveat Empptor!

    The callback has to be threadsafe, and it is not, yet!   #ISSUE

    END
    #:
      my $no-more = 0;
      $no-more = ZMQ_SNDMORE if $part;
      my $more = $no-more +| ZMQ_SNDMORE;

      my $sent = 0;
      my $sending = 0;
      sub callback-f($data, $hint) { say "sending now { --$sending;}" ;}

      my MsgIterator  $it = $!_.iterator;
      my $size = $!_.bytes;
      my $i = 0;
          while $it.has-next {
            my $end = $it.next;
            my zmq_msg_t $msg-t .= new;
            my $ptr = ($end == $i) ?? Pointer !! $!_.offset-pointer($i);
            my $r = $callback
                    ?? zmq_msg_init_data_callback($msg-t,$ptr , $end - $i, &callback-f)
                    !! zmq_msg_init_data($msg-t, $ptr , $end - $i);
            throw-error if $r  == -1;
            my $result = $socket.send-zeromq($msg-t,  ($end == $size) ?? $no-more !! $more , :$async);
            return Any if ! $result.defined;
            $i = $end;
            $sent += $result;
            ++$sending;
          }
          return $sent;
        }

  method bytes( --> Int)         {
     return $!_.next-i;
  }

  method segments( --> Int)         {
    return $!_.offsets.elems;
  }

  method copy() {
     return $!_.buffer.decode('ISO-8859-1');
  }
}

class MsgBuilder is export {
  my $doc= q:to/END/;
  Class MsgBuilder builds a Msg Object that can be used to send complex message
  using zero-copy.

      USAGE example
        my MsgBuilder $builder  .= new;
        my Msg $msg =
          $builder.add($envelope)\
                  .add(-empty)\
                  .add($content-1, -max(1024) -newline)\
                  .add($content-2, -max(1024) -newline)\
                  .finalize;
        $msg.send($msg);



  Methods
      new()
      add( Str, -max-part-sizem -divide-into, -newline --> self)
      add( -empty --> self)
      add( -mewline --> self)
      finalize( --> Msg)

  ATTN - replace - (dash) with colon-dollar in signatures above
            (subtitution is to please Atom syntax-highlighter)
  END
  #:

  has Str $.encoding;   # not implemented yet
  has Bool $.finalized;
  has Buffer $!_;

  method TWEAK {
    $!_ .= new;
    $!_.buffer .= new;
    $!_.offsets .= new;
    $!_.next-i = 0;
    $!finalized = False;
  }

  method !check-finalized() {
    die "MsgBuilder: Ilegal operation on finalized builder" if $!finalized;
  }

  method finalize (--> Msg) {
    self!check-finalized;
    $!finalized = True;
    return Msg.CREATE!Msg::create($!_);
  }

  multi method add( :$empty! --> MsgBuilder) {
    self!check-finalized;
    $!_.offsets().push($!_.next-i);
    return self;
  }

  multi method add( :$newline! --> MsgBuilder) {
    self!check-finalized;
    $!_.buffer[$!_.next-i++] = 10;
    $!_.offsets().push($!_.next-i);
    return self;
  }

  multi method add( Str $part, Int :$max-part-size, Int :$divide-into, :$newline --> MsgBuilder) {
    self!check-finalized;
    my $old-i = $!_.next-i;
    my $max = $max-part-size;
    my $tmp = $part.encode('ISO-8859-1');
    $!_.buffer[$!_.next-i++] = $tmp[$_] for 0..^$tmp.bytes;

    if $divide-into {
      die "cannot divide into a negative" if $divide-into < 0 ;
      $max = ($!_.next-i - $old-i) div $divide-into;
    }

    if $max {
      say " max is $max" ;
      die "max part size cannot be negative" if $max < 0 ;
      $!_.offsets().push($_)
          if ($_ - $old-i) %% $max
            for $old-i^..^$!_.next-i;
    }

    $!_.offsets.push($!_.next-i);
    self.add(:newline) if $newline;
    return self;
  }


}
