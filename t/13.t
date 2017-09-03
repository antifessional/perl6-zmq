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
  my Socket $s1 .= new( $ctx, :server, :throw-everything);
  my Socket $s2 .= new( $ctx, :server, :throw-everything);
  my Socket $s3 .= new( $ctx, :server, :throw-everything);
  my Socket $s4 .= new( $ctx, :server, :throw-everything);
  my Socket $c  .= new( $ctx, :client, :throw-everything);




  my $endpoint = 'inproc://con';
  $s1.connect($endpoint);
  $s2.connect($endpoint);
  $s3.connect($endpoint);
  $s4.connect($endpoint);

  $c.connect($endpoint);

sub rep($s, $m) { $s.send( "$m : Thank You!"); }

my $poll = PollBuilder.new\
        .add(StrPollHandler.new( $s1, sub ($m) { rep($s1, 'S1'); return "got message --$m-- on  socket 1";} ))\
        .add(StrPollHandler.new( $s2, sub ($m) { rep($s2, 'S2'); return "got message --$m-- on  socket 2";} ))\
        .add(StrPollHandler.new( $s3, sub ($m) { rep($s3, 'S3'); return "got message --$m-- on  socket 3";} ))\
        .add($s4, sub { rep($s1, 'S4'); return False })\
        .delay(500)\
        .finalize;

      
      .say while $poll.poll;
      say "Done!";




#  my PollBuilder $pb .= new;
 
# $pb.delay :block;
# $pb.add($s1, $reception);
# my Poll $poll = $pb.finalize;


  $s1.unbind.close;
  $s2.disconnect.close;


done-testing;
