#!/usr/bin/perl -w
use 5.010;
use strict;
use warnings;

use constant N => 1000000;

# Essentially run a no-op many times - This is useful for comparison
# with leak.pl or call.pl


sub run {
    for (1..N) {
        binmode(STDOUT);
    }
}
run();
