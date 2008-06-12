#!/usr/bin/perl -w
use strict;

use constant NO_SUCH_FILE => 'this_file_had_so_better_not_be_here';

use Test::More tests => 5;

eval {
    use autodie qw(system);

    system($^X,'-e1');
};

ok($? == 0, "system completed successfully");

ok(!$@,"system returning 0 is considered fine.") or diag $@;

eval {
    use autodie qw(system);

    system(NO_SUCH_FILE, "foo");
};

ok($@, "Exception thrown");
isa_ok($@, "autodie::exception") or diag $@;

package Bar;

system { $^X } 'perl','-e1';
::ok(1,"Exotic system not harmed");
