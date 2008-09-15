#!/usr/bin/perl -w
use strict;
use Test::More;
use Fcntl qw(:flock);

my $flock_return = flock(STDOUT, LOCK_EX | LOCK_UN);

if (not $flock_return) {
    plan skip_all => "flock not supported on STDOUT on this platform";
}

$flock_return = flock(STDOUT, LOCK_UN);

if (not $flock_return) {
    plan skip_all => "Unlocking of STDOUT not supported on this platform";
}

# If we're here, then we can lock and unlock STDOUT.  So
# let's see if flock works correctly.

# XXX - Write the damn test!

plan skip_all => "The developer was too lazy to write this test.";

