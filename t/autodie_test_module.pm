package main;
use strict;
use warnings;

# Calls open, while still in the main package.  This shouldn't
# be autodying.
sub leak_test {
    return open(my $fh, '<', $_[0]);
}

# This rename shouldn't be autodying, either.
sub leak_test_rename {
    return rename($_[0], $_[1]);
}

package autodie_test_module;

# This should be calling CORE::open
sub your_open {
    return open(my $fh, '<', $_[0]);
}

# This should be calling CORE::rename
sub your_rename {
    return rename($_[0], $_[1]);
}

sub your_dying_rename {
    use autodie qw(rename);
    return rename($_[0], $_[1]);
}

1;
