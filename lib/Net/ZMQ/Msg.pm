#!/usr/bin/env perl6

unit module Net::ZMQ::Msg;
use v6;
use NativeCall;

use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::V4::Constants;

use Net::ZMQ::Error;
use Net::ZMQ::Common;


class Msg is export {
  has zmq_msg_t  $!msgt;
  has buf8      $!buf;
  has bool      $.sent;

    submethod BUILD(:$!buf, :$!size, :$!index
                  ) {
          $!msgt .= new();
          $!hint  = rand 10000;
          $!sent = False;
          zmq_msg_init_data($!msgt, $!buf[index], $!size, &self.callback, 0);
    }

    multi method new(
                        buf8 $buf
                      , Int $size 
                      ,  Int $index = 0
                    ) {
      return self.bless($buf, $size, $index);
    }

    method callback($data, $hint) {
      $!sent = True;
      say "Message Sent $data" ;
    }


}
