#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More tests => 1;

eval {
    use autodie qw(:1.994);

    open(my $fh, '<', 'this_file_had_better_not_exist.txt');
};

isa_ok($@, 'autodie::exception', "Basic version tags work");
