#!/usr/bin/perl -w
use strict;
use Test::More tests => 1;
use constant NO_SUCH_FILE => "this_file_had_better_not_exist";
use autodie;

# This tests RT #50423, Debian #550462

eval {
    chmod(0755, NO_SUCH_FILE);
};

isa_ok($@, 'autodie::exception', 'exception thrown for chmod');

