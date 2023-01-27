#!/usr/bin/perl -w
use strict;
use Test::More;

if (not $ENV{AUTHOR_TESTING}) {
    plan( skip_all => 'Author test.  Set $ENV{AUTHOR_TESTING} to true to run.');
}

eval "use Test::Pod 1.00";  ## no critic
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok();
