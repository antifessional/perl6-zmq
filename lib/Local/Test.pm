
unit module Local::Test;
use v6;
use NativeCall;

sub try-say-rethrow(&f) is export {
    f();
    CATCH {
	default {	    
	    say "### $_.message()  ###";
	    $_.throw(); 
	}
    }
}

#
#  C functions to a local library to allow testing NativeCall functrionality easily
#

sub read_buffer(int32 $opt, buf8 $buf is rw, size_t $len is rw ) 
	  is native( %?RESOURCES{ 'libraries/hello' } ) returns int64 is export
	  { * }

sub read_buffer_int64(int32, CArray[int64], size_t)
    is symbol('read_buffer')
    is native( %?RESOURCES{ 'libraries/hello' } ) returns int64 is export
    { * }

sub read_buffer_int32(int32, int32 is rw, size_t is rw)
    is symbol('read_buffer')
    is native( %?RESOURCES{ 'libraries/hello' } ) returns int64 is export
    { * }

sub hello(int32 $opt )  is native( %?RESOURCES{ 'libraries/hello' } ) is export { * }

