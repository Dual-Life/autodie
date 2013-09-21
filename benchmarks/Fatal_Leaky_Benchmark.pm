use strict;
use warnings;

# But *don't* use autodie
# And *don't* use a package.
# Either of those will stop autodie leaking into this file.

use constant N => 1000000;

# Essentially run a no-op many times. With a high leak overhead,
# this is expensive. With a low leak overhead, this should be cheap.

sub run {
    for (1..N) {
        binmode(STDOUT);
    }
}

1;
