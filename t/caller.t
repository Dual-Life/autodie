#!/usr/bin/perl -w
use strict;
use warnings;
use autodie;
use Test::More 'no_plan';

use constant NO_SUCH_FILE => "kiwifoo_is_so_much_fun";

eval {
    foo();
};

isa_ok($@, 'autodie::exception');
is($@->caller, 'main::foo', "Caller should be main::foo");


sub foo {
    use autodie;
    open(my $fh, '<', NO_SUCH_FILE);
}
