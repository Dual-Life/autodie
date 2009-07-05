#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More tests => 2;

use constant NO_SUCH_FILE => 'this_file_had_better_not_exist';

# Keep this test alone in its file as it can be hidden by using autodie outside
# the eval.

eval q{
    use autodie "open";

    open(my $fh, '<', NO_SUCH_FILE);
};

ok($@, "enabling autodie in string eval should throw an exception");
isa_ok($@, 'autodie::exception');
