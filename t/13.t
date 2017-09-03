#!/usr/bin/env perl6

use v6;

use lib 'lib';

use Test;
use Local::Test;
use NativeCall;

BEGIN %*ENV<PERL6_TEST_DIE_ON_FAIL> = 1;

say  "Polling testing" ;

use-ok  'Net::ZMQ::Poll' , 'Module Poll loads ok';

use Net::ZMQ::V4::Constants;
use Net::ZMQ::Context;
use Net::ZMQ::Socket;
use Net::ZMQ::Message;
use Net::ZMQ::Poll;

  my Context $ctx .= new :throw-everything;
  my Socket $s1 .= new( $ctx, :pair, :throw-everything);
  my Socket $s2 .= new( $ctx, :pair, :throw-everything);
  my $endpoint = 'inproc://con';
  $s1.bind($endpoint);
  $s2.connect($endpoint);

  my PollBuilder $pb .= new;
  my Reception $reception .= new;
 
 $pb.delay :block;
 $pb.add($s1, $reception);
 my Poll $poll = $pb.finalize;


  $s1.unbind.close;
  $s2.disconnect.close;


done-testing;
