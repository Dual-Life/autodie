package pujHa'ghach;

# Translator notes: reH Hegh is Kligon for "always dying".
# It was the original name for this testing pragma, but 
# it lacked an apostrophe, which better shows how Perl is
# useful in Klingon naming schemes.

# The new name is pujHa'ghach is "thing which is not weak".
#   puj   -> be weak (verb)
#   -Ha'  -> not
#   ghach -> normalise -Ha' verb into noun.

use strict;
use warnings;

use base qw(autodie);

sub exception_class {
    return "pujHa'ghach::Dotlh";      # Dotlh - status
}

1;
