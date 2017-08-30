#!/usr/bin/env perl6

unit module Net::ZMQ::Common;
use NativeCall;
use v6;


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
