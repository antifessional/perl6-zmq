#!/usr/bin/env perl6

use v6;

use lib 'lib';

use Test;

BEGIN %*ENV<PERL6_TEST_DIE_ON_FAIL> = 0;

# plan 1;

say "testing context";

use-ok  'Net::ZMQ::Context' , 'Module Context can load';



use Local::Test;
use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::Error;
use Net::ZMQ::Context;

sub contexts() { 
    my $ctx1 = Context.new;
    my $ctx2 = Context.new(throw-everything => False);
    my $ctx3 = Context.new(throw-everything => True);
}

lives-ok {contexts()}, "Contexts can be created and destroyed";

my $ctx1 = Context.new;
my $ctx2 = Context.new(throw-everything => False);
my $ctx3 = Context.new(throw-everything => True);

ok $ctx1.throw-everything == False, "throw-everything Default passed correctly";
ok $ctx2.throw-everything == False, "throw-everything False passed correctly";
ok $ctx3.throw-everything == True, "throw-everything True passed correctly";

is $ctx3.last-error() , ZMQError, "last Error not initialized";

ok $ctx1.shutdown == True, "Null Shutdown passed";

ok $ctx2.test-value() == -1,  "FALLBACK  with no argument works";
ok $ctx2.test-value(19) == 19,  "FALLBACK  with argument works";
ok $ctx2.set-test-value(19) == 19,  "adding set- works";
ok $ctx2.get-test-value() == -1,  "adding get- works";
dies-ok {  try-say-rethrow( sub {$ctx2.get-test-value(19)})},  "adding get- with value exception works";
dies-ok {  try-say-rethrow( sub {$ctx2.set-test-value()})},  "adding set- without value exception works";
dies-ok {  try-say-rethrow( sub {$ctx2.test-values(19)})},  "non-existing option exeption";
dies-ok {  try-say-rethrow( sub {$ctx2.socket-limit(19)})},  "unsettable values are detected";

done-testing;
