#!/usr/bin/env perl6

use v6;

use lib 'lib';

use Test;
use Local::Test;
use NativeCall;

BEGIN %*ENV<PERL6_TEST_DIE_ON_FAIL> = 1;

say  "Test NativeCall mechanisms examples" ;

use-ok  'Net::ZMQ::Common' , 'Common functions loaded';

use Net::ZMQ::V4::Constants;
use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::Context;
use Net::ZMQ::Common;
use Net::ZMQ::Socket;
use Net::ZMQ::Msg;

my $ctx = Context.new(throw-everything => True);
my $s1 = Socket.new($ctx, ZMQ_PAIR, :throw-everything);
my $s2 = Socket.new($ctx, ZMQ_PAIR, :throw-everything);

my $uri = 'inproc://con';
$s1.bind($uri);
$s2.connect($uri);


my $ex = shell "cd lib/Local && make all install clean";

my Str $str1 = "this is a nüll términated string";
my Str $str2 = "this is another beautiful string";
my Str $str3 = "tomorrow the föx wìll comê to town, ho ho ho ho!";
my  $l123 = "$str1\n$str2\n$str3".codes;
my  $l12 = "$str1$str2".codes;


my Msg $msg;
lives-ok { $msg .=new; }, "created Msg";

ok $msg.add($str1, :newline), "addes $str1";
ok $msg.add($str2, :newline), "addes $str1";
ok $msg.add($str3, :max-part-size(20)), "added --$str3-- with max 20";

dies-ok {$msg.bytes }, "unfinalized size fails pass";
$msg.finalize;
dies-ok {$msg.add("another message") }, "finalized add fails pass";

my Int $sl = $s1.send($msg);
ok $l123 == $sl, "message sent with correct length : $l123 -> $sl";

my $rc = $s2.receive :slurp; 
ok $rc.codes == $l123, "message receive with correct length $l123" ;
ok $rc eq $msg.copy, "say message received ok: \n\t$rc";


$s2.disconnect($uri);
$s1.unbind($uri);

$s1.close();
$s2.close();


done-testing;