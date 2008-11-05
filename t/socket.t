#!/usr/bin/perl -w
use strict;

use Test::More;

if (not $ENV{TEST_AUTHOR}) {
    plan( skip_all => 'Author test.  Set $ENV{TEST_AUTHOR} to true to run.');
}

plan tests => 4;

use Socket;
use autodie;

TODO: {
    local $TODO = "getprotobyname not implemented by autodie";

    eval { my $x = getprotobyname('totally bogus') };

    ok($@, "getprotobyname() should die when protocol look-up fails");
}

my $tcp = getprotobyname('tcp');

eval {
    socket(my $socket, PF_INET, SOCK_STREAM, $tcp);

    my $bogus_address = "This isn't even formatted properly";

    connect($socket, $bogus_address);
};

isa_ok($@, 'autodie::exception');
ok($@->matches('connect'), "connect threw an exception");

TODO: {
    local $TODO = "connect doesn't have pretty messages yet";

    unlike($@, qr/GLOB/, "We shouldn't show ugly GLOB(...)s ever");
}
