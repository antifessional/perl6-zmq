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


my $msg;
lives-ok { $msg = MsgBuilder.new; }, "created Msg";

ok $msg.add($str1, :newline).defined , "addes $str1";
ok $msg.add($str2, :newline).defined, "addes $str1";
ok $msg.add($str3, :max-part-size(20)).defined, "added --$str3-- with max 20";

dies-ok {$msg.bytes }, "unfinalized size fails pass";
my $builder = $msg;
$msg = $msg.finalize;
dies-ok {$msg.add("another message") }, "finalized add fails pass";


my Int $sl = $msg.send($s1);
ok $l123 == $sl, "message sent with correct length : $l123 -> $sl";

my $rc = $s2.receive :slurp; 
ok $rc.codes == $l123, "message receive with correct length $l123" ;
ok $rc eq $msg.copy, "say message received ok: \n\t$rc";

my $lsent = "$str1\n$str2\n$str3\n".codes;
my $sent =
          MsgBuilder.new\
                  .add($str1,  :newline)\
                  .add( :empty)\
                  .add($str2, :max(1024), :newline)\
                  .add($str3, :max(1024), :newline)\
                  .add( :empty)\
                  .finalize.send($s2, :callback );
my $unsent =
          MsgBuilder.new\
                  .add($str1,  :newline)\
                  .add( :empty)\
                  .add($str2, :max(1024), :newline)\
                  .add($str3, :max(1024), :newline)\
                  .finalize;



ok $sent == $lsent, "builder -> msg -> sent correct : $sent == $lsent" ;
$rc = $s1.receive :slurp; 
ok $rc.codes == $lsent, "message receive with correct length $lsent" ;
ok $rc eq $unsent.copy, "say message received ok: \n$rc\n{$unsent.copy}";

my $sempty =
          MsgBuilder.new\
#                  .add($str1,  :newline)\
                  .add( :empty)\
                  .finalize.send($s2);
$rc = $s1.receive :slurp; 
say "--$rc-- : sent $sempty";

$s2.disconnect($uri);
$s1.unbind($uri);

$s1.close();
$s2.close();

done-testing;