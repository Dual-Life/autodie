package pujHa'ghach::Dotlh;

# Translator notes: Dotlh = status

# Ideally this should be le'wI' - Thing that is exceptional. ;)
# Unfortunately that results in a file called .pm, which may cause
# problems on some filesystems.

use strict;
use warnings;

use base qw(autodie::exception);

sub stringify {
    my ($this) = @_;

    my $base_str = $this->SUPER::stringify;

    return "Klingon exception: $base_str\n";

}

1;


