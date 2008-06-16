package autodie_test_module;
use strict;
use warnings;

sub main_open {
    return main::open(my $fh, '<', $_[0]);
}

sub your_open {
    return open(my $fh, '<', $_[0]);
}

1;
