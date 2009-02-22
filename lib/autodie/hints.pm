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

use constant DEFAULT_HINTS => 0;

# Only ( undef ) is a strange but possible situation for very
# badly written code.  It's not supported yet.

# TODO: Should we allow 'File::Copy::*' as a hash key?  This
# would be useful for modules which have lots of subs which
# express the same interface.

my %hints = (
    'File::Copy::copy' => LIST_EMPTY_OR_FALSE,
    'File::Copy::move' => LIST_EMPTY_OR_FALSE,
);

# Start by using Sub::Identify if it exists on this system.

eval { require "Sub::Identify"; Sub::Identify->import('get_code_info'); };

# If it doesn't exist, we'll define our own.  This code is directly
# taken from Rafael Garcia's Sub::Identify 0.04, used under the same
# license as Perl itself.

if ($@) {
    require B;

    no warnings 'once';

    *get_code_info = sub ($) {

        my ($coderef) = @_;
        ref $coderef or return;
        my $cv = B::svref_2object($coderef);
        $cv->isa('B::CV') or return;
        # bail out if GV is undefined
        $cv->GV->isa('B::SPECIAL') and return;

        return ($cv->GV->STASH->NAME, $cv->GV->NAME);
    };

}

sub sub_fullname {
    return join( '::', get_code_info( $_[1] ) );
}

sub get_hints_for {
    my ($class, $sub) = @_;

    my $hints = $hints{ $class->sub_fullname( $sub ) };

    return defined($hints) ? $hints : DEFAULT_HINTS;

}

1;

