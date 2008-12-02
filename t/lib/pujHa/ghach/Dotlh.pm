package pujHa'ghach::Dotlh;

# Translator notes: Dotlh = status

use strict;
use warnings;

use base qw(autodie::exception);

sub stringify {
    my ($this) = @_;

    my $base_str = $this->SUPER::stringify;

    return "Klingon exception: $base_str\n";

}

1;


