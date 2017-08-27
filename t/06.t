#!/usr/bin/env perl6

use v6;

use lib 'lib';

use Test;

use Local::Test;

say "testing context 2";

BEGIN %*ENV<PERL6_TEST_DIE_ON_FAIL> = 0;

# plan 1;

use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::Error;
use Net::ZMQ::Context;


my $ctx4 = Context.new(throw-everything => True);
my $thrds = $ctx4.io-threads();
my $changing = $ctx4.io-threads(2);
my $thrds2 =  $ctx4.io-threads();
ok $thrds2 == 2, "setting io threads number passed before: $thrds RET: $changing after: $thrds2"; 


done-testing;
