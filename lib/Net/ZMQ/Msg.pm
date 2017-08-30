#!/usr/bin/env perl6

unit module Net::ZMQ::Msg;
use v6;
use NativeCall;

use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::V4::Constants;

use Net::ZMQ::Error;
use Net::ZMQ::Common;

class Msg {...}

class MsgBuilder {


}


class MsgIterator is export {
  has Msg $!msg;
  has Int $!i;
  has Int $!offset;
  has Int $!segments;
  my $doc = q:to/END/;

    Forward Iterator over the Msg class, returns a series of segments sizes in
    bytes!    use as

      my $it = $msg.get-terator;
      my $from = 0;
      while $it->has-next {
        $next = $it.next;
        say "segment is from offset $from to { $next - 1 }";
        $from = $next;
      }

  END
  #:


  method TWEAK {
    die "MsgIterator needs an instance" unless $!msg.defined;
    $!i = 0;
    $!offset = Int;
    $!segments := $!msg.segments;
  }

  # this shouldn't be necessary ???
  submethod BUILD( :$msg ) { $!msg := $msg; }

  method new(Msg $msg) {
    return self.bless( :$msg );
  }

  method next( --> Int  ) {
      die "illegal offset" if $!offset > $!msg.bytes;
      return $!offset;
  }

  method has-next( --> Bool)  {
    return False if $!i == $!segments;
    $!offset = $!msg.offset( $!i++ );
    die "asserting offset not in overflow" unless ($!offset <= $!msg.bytes);
    return True;
  }
}


class Msg is export {
  my $doc = q:to/END/;

    class Msg wraps a byte buffer (buf8) for use for sending complex multi-part messages fast
    Msg objects have two phases with a distinct set of methods available in each.
    A message is either being built or it has been finalized and is immutable

    Attributes
      encoding   # not implemented yet
      finalized

    Build phase Methods
        add( Str , -max-part-size -divide-into)
        add( -empty)
        finalize()

    Finalized phase Methods
          offset(Int segment --> Int)  - returns the position after the end of the segment
          iterator( --> MsgIterator)  - return a segment Iterator
          offset-pointer(Int i --> Pointer) - returns a Pointer to the buffer's byte i location in memory
          bytes( --> Int)
          segments( --> Int)



  END
  #:


  has Str $.encoding;   # not implemented yet

  has buf8 $!buffer;
  has uint @!offsets;
  has Bool $!finalized;
  has Int $!next-i;

 method TWEAK {
   $!buffer .= new;
   @!offsets .= new;
   $!finalized = False;
   $!next-i = 0;
 }

  method !check-finalized(Bool $state ) {
    die "Msg: Ilegal operation, Msg is not finalized" if $state && ! $!finalized;
    die "Msg: Ilegal operation, finalized Msg is immutable" if ! $state && $!finalized;
  }

## build
  multi method add( :$empty! --> Bool) {
    @!offsets.push($!next-i);
    return True;
  }
  multi method add( :$newline! --> Bool) {
    $!buffer[$!next-i++] = 10;
    @!offsets.push($!next-i);
    return True;
  }

  multi method add( Str $part, Int :$max-part-size, Int :$divide-into, :$newline --> Bool) {
    self!check-finalized(False);
      my $old-i = $!next-i;
      my $max = $max-part-size;
      my $tmp = $part.encode('ISO-8859-1');
      $!buffer[$!next-i++] = $tmp[$_] for 0..^$tmp.bytes;

      if $divide-into {
        die "cannot divide into a negative" if $divide-into < 0 ;
        $max = ($!next-i - $old-i) div $divide-into;
      }

      if $max {
        say " max is $max" ;
        die "max part size cannot be negative" if $max < 0 ;
        @!offsets.push($_)
          if ($_ - $old-i) %% $max
            for $old-i^..^$!next-i;

      }

      @!offsets.push($!next-i);
      self.add(:newline) if $newline;
      return True;
  }

  method finalize( --> Bool ) {
    self!check-finalized(False);
    die "Msg: size mismatch assertion" if $!buffer.bytes != $!next-i;
    say "next-i: $!next-i\nsegments : @!offsets.elems()\n\t{@!offsets.gist}";
    $!finalized = True;
  }

#access
  method offset(Int $i --> Int)  {
    self!check-finalized(True);
    die "Msg: illegal offset" if $i >= @!offsets.elems;
    return @!offsets[$i];
  }

  method iterator( --> MsgIterator) {
    self!check-finalized(True);
    return MsgIterator.new(self);
  }

  method offset-pointer(Int $i --> Pointer )  {
    self!check-finalized(True);
    die "Msg: buffer overflow" if $i >= $!next-i;
    ## c hack here ##
    return buf8-offset($!buffer, $i);
  }

  method bytes( --> Int)         {
    self!check-finalized(True);
    return $!next-i;
  }

  method segments( --> Int)         {
    self!check-finalized(True);
    return @!offsets.elems;
  }

  method copy() {
    return $!buffer.decode('ISO-8859-1');
  }

}
