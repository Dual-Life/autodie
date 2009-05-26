package autodie::hints::provider;
use strict;
use warnings;

our $VERSION = '1.999_01';

sub AUTODIE_HINTS {
    my ($class) = @_;
    die "$class inherits from autodie::hints::provider but does not define its own AUTODIE_HINTS() method, or tries to call this method in its parent class.  Please create an AUTODIE_HINTS() method for this class, or remove its inheritance on autodie::hints::provider";

}

# Dummy package for inheritance.

1;

__END__

=head1 NAME

autodie::hints::provider - Abstract class for autodie hints

=head1 SYNOPSIS

    use base qw(autodie::hints::provider);

    sub AUTODIE_HINTS {
        ...
    }

=head1 DESCRIPTION

This is an abstract class to indicate that a given class
provides hints for autodie by implementing the C<AUTODIE_HINTS>
method.

If you are using Perl 5.10.0 or above, or otherwise have an
implementation of C<UNIVERSAL::DOES>, then it is recommended that
your class I<DOES> C<autodie::hints::provider>, rather than
inheriting it.

=head1 AUTHOR

Paul Fenwick

=cut
