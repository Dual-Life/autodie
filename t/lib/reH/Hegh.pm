package reH::Hegh;

# Translator notes: reH Hegh is Kligon for "always dying".

use strict;
use warnings;

use base qw(autodie);

sub exception_class {
    return "reH::Hegh::Dotlh";      # Dotlh - status
}

1;
