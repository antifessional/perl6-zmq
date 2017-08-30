#!/usr/bin/env perl6

unit module Net::ZMQ::Msg;
use v6;
use NativeCall;

use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::V4::Constants;

use Net::ZMQ::Error;
use Net::ZMQ::Common;


class MsgIterator {
  has Msg $!msg;  
  has Int $!i;
  has Int $!acc;
    
    method next( --> Int  ) { 
      die "illegal offset" if $!acc >= $!msg.size ;
      $!acc = msg.offsets[ $!i ]; 
      return $!acc; 
    }
    method has-next( --> Bool)  { return $!acc >= $!msg.size;  }
}


class Msg is export {
  has buf8 $.buffer;
  has uint @.offsets;
  has Str $.encoding;



  method add( Str $part) {...}
  method reset( Str $part) {...}


}
