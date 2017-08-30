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
use Net::ZMQ::Common;

my $ex = shell "cd lib/Local && make all install";

my Str $s = "this is a nüll términated string";
my buf8 $b .= new($s.encode('utf-8'));
my int64 $lb = $b.bytes;
my $slen =  read_buffer(3, $b, $lb);
ok $slen = $b.bytes, "passed @ $s :: $lb @ { ($s.chars, $b.bytes).perl } , got back $slen" ;

my buf8 $p := buf8.new( 
    [84, 104, 105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 
	110, 103, 32, 109, 97, 100, 195, 169, 32, 111, 102, 32, 97, 115,
	 99, 105, 105, 32, 99, 104 ,97, 114 ,99 ,116 ,101 ,114 ,115 ,32,
	 119, 105, 116 ,104, 111, 117 ,116 ,32 ,110 ,195, 188, 108 ,108 ,46]);
my int64 $al = $p.bytes;
my $alenr =  read_buffer(4, $p, $al);
ok $alenr = $al+1, "passed @ ASCII array :: $al @ got back $alenr" ;


my $filename = 'dump';
$ex = shell "rm -f $filename > /dev/null 2>&1" ;
my buf8 $raw = slurp "lib/Local/hello", :bin;
my int64 $lraw = $raw.bytes;
my $lrawr =  read_buffer(5, $raw, $lraw);
ok $lraw = $lrawr, "binary file transfered to C counted correctly";
ok  0 == shell "chmod a+x $filename";
my $output = qq:x! "./$filename"!;
ok $output eq "Hello World\n", "running transferd binary passed";
$ex = shell "rm -f $filename";
$ex = shell "cd lib/Local && make clean";

my buf8 $buf .= new(| $s.encode('ISO-8859-1'));
my $arr = CArray[uint8].new;
say box_array($buf , 0);
say box_array2($arr , 0);
say box_array($buf , 10);
say box_array2($arr , 10);


done-testing;