package autodie;
use 5.010;
use strict;
use warnings;

use Fatal ();
our $VERSION = $Fatal::VERSION;

# When passing args to Fatal we want to keep the first arg
# (our package) in place.  Hence the splice.

# TODO: Consider making a bare 'use autodie' the same as
# 'use autodie qw(:all)'.

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

	bIlujDI' yIchegh()Qo'; yIHegh()!

	It is better to die() than to return() in failure.

                -- Klingon programming proverb.

The C<autodie> pragma provides a convenient way to replace functions
that normally return false on failure with equivalents that throw
an exception on failure.

The C<autodie> pragma has I<lexical scope>, meaning that functions
and subroutines altered with C<autodie> will only change their behaviour
until the end of the enclosing block, file, or C<eval>.

=head1 EXCEPTIONS

Exceptions produced by the C<autodie> pragma are members of the
L<autodie::exception> class.  The preferred way to work with
these exceptions is as follows:

	use feature qw(switch);

	eval {
		use autodie ':io';

		open(my $fh, '<', $some_file);

		my @records = <$fh>;

		close($fh);

	};

	given ($@) {
		when (undef)   { say "No error";                    }
		when ('open')  { say "Error from open";             }
		when (':io')   { say "Non-open, IO error.";         }
		when (':all')  { say "All other autodie errors."    }
		default        { say "Not an autodie error at all." }
	}


=head1 AUTHOR

Copyright 2008, Paul Fenwick E<lt>pjf@perltraining.com.auE<gt>

=head1 LICENSE

This module is free software.  You may distribute it under the
same terms as Perl itself.

=head1 SEE ALSO

L<Fatal> L<autodie::exception>

=cut
