#!/usr/bin/env perl6

unit module Net::ZMQ::Poll;
use v6;
use NativeCall;

use Net::ZMQ::V4::LowLevel;
use Net::ZMQ::V4::Constants :DEFAULT, :IOPLEX ;

use Net::ZMQ::Error;
use Net::ZMQ::Common;
use Net::ZMQ::Socket;

role CArray-CStruct[Mu:U \T where .REPR eq 'CStruct'] does Positional[T] {
  my $doc = q:to/END/;
  see
  https://stackoverflow.com/questions/43544931/passing-an-array-of-structures-to-a-perl-6-nativecall-function
  END
  #:

    has $.bytes;
    has $.elems;

    method new(UInt \n) {
        my $sz = nativesizeof T;
        say "allocating {n} times $sz";
        self.bless(bytes => buf8.allocate(n * nativesizeof T), elems => n);
    }

    method AT-POS(UInt \i where ^$!elems) {
        my $offset = i * nativesizeof T;
        my $base = nativecast(Pointer, $!bytes);
        my $pos = i;
        say "c-int [ $pos = { $base.gist } + $offset  ]";
        nativecast(T, Pointer.new(nativecast(Pointer, $!bytes) + i * nativesizeof T));
    }

    method Pointer {
        nativecast(Pointer[T], $!bytes);
    }
}


my %poll-events = incoming => ZMQ_POLLIN
                  , outgoing => ZMQ_POLLOUT;

role Reception is export {

  method nibbler( --> Callable) {
    return sub ( Socket:D $socket ) {
      say "got to feed on message parts from Socket { $socket.perl }";
      #my $msg = $socket.receive :slurp;
      #say $msg;
      return Sub;
    }
  }
}

class PollBuilder {...}

class PolledReceiver {
  has Socket $.socket = die "Polled socket cannot be undefined";
  has Reception $.reception  = die "Polled socket cannot be undefined";
}

class Poll-impl {

  has PolledReceiver @.items is rw handles < elems >;
  has Int $.delay is rw = Int;
  has @.c-items is rw;

  method add( Socket:D :$socket!, Reception:D :$reception!) {
    @!items.push( PolledReceiver.new(:$socket, :$reception));
  }

  method finalize()   {
    @!c-items := CArray-CStruct[ zmq_pollitem_t ].new(self.elems);

    for ^self.elems -> $n {
     # @!c-items[$n] .= new(:socket(@!items[$n].socket.handle)
     #                         , :fd:(0)
     #                       , :events(%poll-events<incoming>)
     #                        , :revents(0));
      @!c-items[$n].socket = @!items[$n].socket.handle;
      @!c-items[$n].fd = 0;
      @!c-items[$n].events = %poll-events<incoming>;
      @!c-items[$n].revents = 0;
    }
  }

  method poll( --> PolledReceiver ) {
    die "cannot poll un unfinalized Poll" unless @!c-items.defined;
    throw-error()  if -1 == zmq_poll( @!c-items, self.elems, $!delay);
    for @!c-items.kv -> $n, $item {
        return @!items[$n] if ( $item.revents +& %poll-events<incoming> );
    }
    return PolledReceiver;
  }
}



class Poll is export {
  trusts PollBuilder;
  has Poll-impl $!pimpl handles < elems >;

  method new  {die "Poll: private constructor";}
  method !create( Poll-impl:D $pimpl)   {return self.bless(:pimpl($pimpl)); }

  method poll() {
    my PolledReceiver $pr = $!pimpl.poll;

    my Socket $socket = $pr.socket;
    my Callable $nibbler = $pr.reception.nibbler;
    loop {
        $nibbler = $nibbler($socket);
        last if ! $nibbler.defined;
    }
    die "The Polling Reception { $pr.reception.perl }"
          ~" left unwashed dishes in the sink." if $socket.incomplete;
  }
}


class PollBuilder is export {
  has Poll-impl $!pimpl .= new;
  has Bool $!finalized = False;

  method !check-finalized()  {
    die "PollBuilder: cannot change finalized Poll" if $!finalized;
  }

  method finalize() {
    self!check-finalized();
    die "PollBuilder: you forgot to set a delay" if ! $!pimpl.delay.defined;
    die "PollBuilder: there must be something to poll in a poll" if $!pimpl.elems == 0;
    $!finalized = True;
    $!pimpl.finalize;
    return Poll.CREATE!Poll::create($!pimpl);
  }

  multi method delay( :$block!) { $!pimpl.delay = -1; return self;}
  multi method delay( Int:D $delay ) { $!pimpl.delay = $delay; return self;}

  method add( Socket:D $s, Reception:D $r  ) {
    self!check-finalized;
    $!pimpl.add(:socket($s), :reception($r)) ;
    return self;
  }

}
