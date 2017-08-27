#!/usr/bin/env perl6

unit module Net::ZMQ::Context;
use v6;
use NativeCall;

use Net::ZMQ::Error;
use Net::ZMQ::Common;
use Net::ZMQ::ContextOptions;
use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::V4::Constants;

class Context does ContextOptions is export {
    has Pointer $.ctx; 
    has bool $.throw-everything;
    has ZMQError $.last-error;

    submethod BUILD(:$!throw-everything = False){
        $!ctx := zmq_ctx_new();
	throw-error()  if ! $!ctx;
    }

    method new(:$throw-everything = False) {
	return self.bless(:$throw-everything);
    }

    method DESTROY() {
        throw-error() if zmq_ctx_term( $!ctx ) == -1
			&& $.throw-everything;
    }

    method !terminate() {
	my $result := zmq_ctx_term( $!ctx );
	if $result != 0 {
	    $!last-error = $.throw-everything ?? throw-error() !! get-error();
	}
	return $result == 0;
    }

    method shutdown() {
	my $result := zmq_ctx_shutdown( $!ctx );
	if $result != 0 {
	    $!last-error = $.throw-everything ?? throw-error() !! get-error();
	}
	return $result == 0;
    }

    method get-option(Int $opt) {
	my $result := zmq_ctx_get($!ctx, $opt);
	if $result == -1 {
	    $!last-error = $.throw-everything ?? throw-error() !! get-error();
	}
	return $result;
    }

    method set-option(Int $opt, Int $value) {
	my $result := zmq_ctx_set($!ctx, $opt, $value);
	if $result != 0 {
	    $!last-error = $.throw-everything ?? throw-error() !! get-error();
	}

	return $result == 0;
    }

    method FALLBACK($name, |c(Int $value = Int)) { 
	
	my $set-get := $value.defined ?? 'set' !! 'get';
	my $method := $name.substr(0,4) eq "$set-get-"  ?? $name.substr(4) !! $name;
	my $code := self.option( $method, 'code') ;

	die "Context: unrecognized option request : { ($name, $value).perl }"
	    if ! $code.defined;

	my $can-do := self.option( $method, $set-get );

	die   "Context: { $value.defined ?? 'set' !! 'get'}ting this option not allowed: { ($name, $value).perl }"
	    if ! $can-do;

	return $value // -1 if $code == ZMQ_TEST;

	return $value.defined ?? self.set-option($code, $value) 
				  !! self.get-option($code);
    }
}


