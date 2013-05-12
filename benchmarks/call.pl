#!/usr/bin/perl -w
use 5.010;
use strict;
use warnings;
use autodie qw(binmode);

use constant N => 1000000;

# Run an autodie wrapped sub many times in what's essentially a no-op.
# This should give us an idea of autodie's overhead.

for (1..N) {
    binmode(STDOUT);
}
