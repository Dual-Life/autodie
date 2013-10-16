package autodie::Scope::Guard;

use strict;
use warnings;

# This code schedules the cleanup of subroutines at the end of
# scope.  It's directly inspired by chocolateboy's excellent
# Scope::Guard module.

sub new {
    my ($class, $handler) = @_;

    return bless($handler, $class);
}

sub DESTROY {
    my ($self) = @_;

    $self->();
}

1;
