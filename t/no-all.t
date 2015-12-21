#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 1;
use autodie qw(:all);

use_system();
ok("system() works with a lexical 'no autodie' block (github issue #69");

sub break_system {
    no autodie;
}

sub use_system {
    system($^X, '-e' , 1);
}
