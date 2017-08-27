#!/usr/bin/env perl6

unit module Net::ZMQ;

use v6;
#use NativeCall;

use Net::ZMQ::Version;
use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::V4::Constants :ALL :EXPORT;  

#test
say "This Module should export a large number of symbols, but it doesn't :( ";

