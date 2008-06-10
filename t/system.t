#!/usr/bin/perl -w
use strict;

use constant NO_SUCH_FILE => 'this_file_had_so_better_not_be_here';

use Test::More tests => 3;

eval {
    use autodie qw(system);

    system($^X,'-e1');
};

ok($? == 0, "system completed successfully");

ok(!$@,"system returning 0 is considered fine.");

package Bar;

system { $^X } 'perl','-e1';
::ok(1,"Exotic system not harmed");
