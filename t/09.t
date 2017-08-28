#!/usr/bin/env perl6

use v6;

use lib 'lib';

use Test;
use Local::Test;

BEGIN %*ENV<PERL6_TEST_DIE_ON_FAIL> = 0;

say  "Sending and receiving a binary file";

use-ok  'Net::ZMQ::Socket' , 'Module Socket can load';

use Net::ZMQ::V4::Constants;
use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::Error;
use Net::ZMQ::Context;
use Net::ZMQ::Socket;


say "testing PAIRed sockets"; 

my $ctx = Context.new(throw-everything => True);
my $s1 = Socket.new($ctx, ZMQ_PAIR, True);
my $s2 = Socket.new($ctx, ZMQ_PAIR, True);

pass "Sockets created ...pass";

my $uri = 'inproc://con';

lives-ok  {$s1.bind($uri)}, 's1 binds succesfully' ;
lives-ok  {$s2.connect($uri)}, 's2 connects succesfully' ;;


if 1 {
my $ex = shell "cd lib/Local && make all install";

my $filename = 'dump';
$ex = shell "rm -f $filename > /dev/null 2>&1" ;

my buf8 $raw = slurp "lib/Local/hello", :bin;

my int64 $lraw = $raw.bytes;
my $lrawr =  $s1.send($raw);
ok $lraw = $lrawr, "binary file transfered to C counted correctly";

my $rcvd = $s2.receive :bin;
ok $lrawr == $rcvd.bytes , "received binary { $rcvd.bytes }" ;

spurt "$filename", $rcvd, :bin, :createonly;
ok  0 == shell "chmod a+x $filename";
my $output = qq:x! "./$filename"!;
ok $output eq "Hello World\n", "running transferd binary passed";

$ex = shell "rm -f $filename";
$ex = shell "cd lib/Local && make clean";

pass "file reconstituted correctly";
}


$s2.disconnect($uri);
$s1.unbind($uri);
$s1.close();
$s2.close();
pass "closing sockets pass";


done-testing;
