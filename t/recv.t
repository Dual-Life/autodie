#!/usr/bin/perl -w
use strict;
use 5.010;
use Test::More;
use Socket;
use autodie qw(socketpair);

my ($sock1, $sock2);
socketpair($sock1, $sock2, AF_UNIX, SOCK_STREAM, PF_UNSPEC);

my $buffer;
send($sock1, "xyz", 0);
my $ret = recv($sock2, $buffer, 2, 0);

if ($ret) {
	plan skip_all => 'Tests meaningless with socketpair emulation';
}

plan tests => 3;

use autodie('recv');

is($buffer,'xy',"recv() operational without autodie");

# Read the last byte from the socket.
$ret = recv($sock2, $buffer, 1, 0);

is($buffer,"z","recv() operational with autodie");
is($ret,"","recv returns undying empty string for local sockets");

