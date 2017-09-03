#!/usr/bin/env perl6

unit module Net::ZMQ::Common;
use NativeCall;
use v6;

=begin c
sub carray-int8-offset(CArray[uint8], int32 )
	  is native( %?RESOURCES{ 'libraries/p6zmq' } ) 
      returns Pointer 
      is symbol('array_offset_byte')
      is export  { * }

sub buf8-offset(buf8, int32 )
	  is native( %?RESOURCES{ 'libraries/p6zmq' } ) 
      returns Pointer 
      is symbol('array_offset_byte')
      is export  { * }
=end c
=cut


role CArray-CStruct[Mu:U \T where .REPR eq 'CStruct'] does Positional[T] {
  my $doc = q:to/END/;
  see
  https://stackoverflow.com/questions/43544931/passing-an-array-of-structures-to-a-perl-6-nativecall-function
  END
  #:

    has $.bytes;
    has $.elems;

    method new(UInt \n) {
        self.bless(bytes => buf8.allocate(n * nativesizeof T), elems => n);
    }

    method AT-POS(UInt \i where ^$!elems) {
        nativecast(T, Pointer.new(nativecast(Pointer, $!bytes) + i * nativesizeof T));
    }

    method as-pointer {
        nativecast(Pointer[T], $!bytes);
    }
}
