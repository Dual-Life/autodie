#!/usr/bin/perl -w
use strict;

use Test::More;

if (not $ENV{RELEASE_TESTING}) {
    plan( skip_all => 'Author test.  Set $ENV{RELEASE_TESTING} to true to run.');
}

eval { require Test::Kwalitee; Test::Kwalitee->import() };
plan( skip_all => 'Test::Kwalitee not installed; skipping' ) if $@;
