package autodie;
use 5.010;
use strict;
use warnings;

use Fatal ();
our @ISA = qw(Fatal);

# When passing args to Fatal we want to keep the first arg
# (our package) in place.  Hence the splice.

sub import {
	splice(@_,1,0,Fatal::LEXICAL_TAG);
	goto &Fatal::import;
}

sub unimport {
	splice(@_,1,0,Fatal::LEXICAL_TAG);
	goto &Fatal::unimport;
}

1;

__END__

=head1 NAME

autodie - Replace functions with ones that succeed or die with lexical scope

=head1 SYNOPSIS

    use autodie qw(open close);	# open/close succeed or die

    {
        no autodie qw(open);	# open fails normally

        no autodie;		# disable all autodies
    }

=head1 DESCRIPTION

The C<autodie> pragma is a shortcut to C<use Fatal qw(:lexical)>.
Please see the L<Fatal> documentation for more information.

=head1 AUTHOR

Paul Fenwick <pjf@perltraining.com.au>

=head1 LICENSE

This module is free software.  You may distribute it under the
same terms as Perl itself.

=head1 SEE ALSO

L<Fatal> upon which this module is merely a thin wrapper.

=cut
