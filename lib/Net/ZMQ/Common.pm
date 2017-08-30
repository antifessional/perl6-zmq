#!/usr/bin/env perl6

unit module Net::ZMQ::Common;
use NativeCall;
use v6;


sub box_array(buf8, int32 )
	  is native( %?RESOURCES{ 'libraries/box' } ) 
      returns Pointer 
      is symbol('box_carray')
      is export
	  { * }

#=begin c
sub box_array2(CArray, int32 ) 
	  is native( %?RESOURCES{ 'libraries/box' } )
      is symbol('box_carray') 
      returns Pointer 
      is export
	  { * }
#=end c
