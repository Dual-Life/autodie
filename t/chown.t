#!/usr/bin/perl -w
use strict;
use Test::More tests => 1;
use constant NO_SUCH_FILE => "this_file_had_better_not_exist";
use autodie;

eval {
    chown(1234, 1234, NO_SUCH_FILE);
};

isa_ok($@, 'autodie::exception', 'exception thrown for chown');

