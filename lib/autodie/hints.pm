package autodie::hints;

use strict;
use warnings;

# This file contains hints on how user-defined subroutines should
# be handled.  For scalar context, there are two options:

use constant SCALAR_ANY_FALSE   => 0;   # Default
use constant SCALAR_UNDEF_ONLY  => 1;

# For list context, there are more options:

use constant LIST_EMPTY_OR_UNDEF => 0;  # Default
use constant LIST_EMPTY_ONLY     => 2;
use constant LIST_EMPTY_OR_FALSE => 4;

# Only ( undef ) is a strange but possible situation for very
# badly written code.  It's not supported yet.

# TODO: Should we allow 'File::Copy::*' as a hash key?  This
# would be useful for modules which have lots of subs which
# express the same interface.

my %hints = (
    'File::Copy::copy' => LIST_EMPTY_OR_FALSE,
    'File::Copy::move' => LIST_EMPTY_OR_FALSE,
);



1;
