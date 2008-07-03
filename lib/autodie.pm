package autodie;
use 5.008;
use strict;
use warnings;

use Fatal ();
our @ISA = qw(Fatal);
our $VERSION;

BEGIN {
    $VERSION = "1.10_08";
}

use constant ERROR_WRONG_FATAL => q{
Incorrect version of Fatal.pm loaded by autodie.

The autodie pragma uses an updated version of Fatal to do its
heavy lifting.  We seem to have loaded Fatal version %s, which is
probably the version that came with your version of Perl.  However
autodie needs version %s, which would have come bundled with
autodie.

You may be able to solve this problem by adding the following
line of code to your main program, before any use of Fatal or
autodie.

    use lib "%s";

};

# We have to check we've got the right version of Fatal before we
# try to compile the rest of our code, lest we use a constant
# that doesn't exist.

BEGIN {

    # If we have the wrong Fatal, then we've probably loaded the system
    # one, not our own.  Complain, and give a useful hint. ;)

    if ($Fatal::VERSION ne $VERSION) {
        my $autodie_path = $INC{'autodie.pm'};

        $autodie_path =~ s/autodie\.pm//;

        require Carp;

        Carp::croak sprintf(
            ERROR_WRONG_FATAL, $Fatal::VERSION, $VERSION, $autodie_path
        );
    }
}

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

    use autodie;    # Recommended, implies 'use autodie qw(:all)'

    use autodie qw(open close);   # open/close succeed or die

    open(my $fh, "<", $filename); # No need to check! 

    {
        no autodie qw(open);          # open failures won't die
        open(my $fh, "<", $filename); # Could fail silently!
        no autodie;                   # disable all autodies
    }

=head1 DESCRIPTION

        bIlujDI' yIchegh()Qo'; yIHegh()!

        It is better to die() than to return() in failure.

                -- Klingon programming proverb.

B<NOTE!  This is BETA code.  It is NOT the final release.  Implementation
and interface may change!>

The C<autodie> pragma provides a convenient way to replace functions
that normally return false on failure with equivalents that throw
an exception on failure.

The C<autodie> pragma has I<lexical scope>, meaning that functions
and subroutines altered with C<autodie> will only change their behaviour
until the end of the enclosing block, file, or C<eval>.

If C<system> is specified as an argument to C<autodie>, then it
uses L<IPC::System::Simple> to do the heavy lifting.  See the
description of that module for more information.

=head1 EXCEPTIONS

Exceptions produced by the C<autodie> pragma are members of the
L<autodie::exception> class.  The preferred way to work with
these exceptions under Perl 5.10 is as follows:

    use feature qw(switch);

    eval {
        use autodie;

        open(my $fh, '<', $some_file);

        my @records = <$fh>;

        # Do things with @records...

        close($fh);

    };

    given ($@) {
        when (undef)   { say "No error";                    }
        when ('open')  { say "Error from open";             }
        when (':io')   { say "Non-open, IO error.";         }
        when (':all')  { say "All other autodie errors."    }
        default        { say "Not an autodie error at all." }
    }

Under Perl 5.8, the C<given/when> structure is not available, so the
following structure may be used:

    eval {
        use autodie;

        open(my $fh, '<', $some_file);

        my @records = <$fh>;

        # Do things with @records...

        close($fh);
    };

    if ($@ and $@->isa('autodie::exception')) {
        if ($@->matches('open')) { print "Error from open\n";   }
        if ($@->matches(':io' )) { print "Non-open, IO error."; }
    } elsif ($@) {
        # A non-autodie exception.
    }

See L<autodie::exception> for further information on interrogating
exceptions.

=head1 GOTCHAS

Functions called in list context are assumed to have failed if they
return an empty list, or a list consisting only of a single undef
element.

A bare autodie will change from meaning C<:all> to C<:default>
before the final release.  There is the possibility for C<:default>
may contain user-defined subs, or for some built-ins that exist in
C<:all> to have been removed from C<:default>.

=head1 DIAGNOSTICS

=over 4

=item :void cannot be used with lexical scope

The C<:void> option is supported in L<Fatal>, but not
C<autodie>.  If you want a block of code with C<autodie>
turned off, use C<no autodie> instead.

=back

=head1 BUGS

Applying C<autodie> to C<system> causes the exotic C<system { ... } @args >
form to be considered a syntax error until the end of the lexical scope.
If you really need to use the exotic form, you can call C<CORE::system>
instead.

There are plenty more bugs!  See
L<http://github.com/pfenwick/autodie/tree/master/TODO> for a selection
of what's remaining to be fixed.

=head1 AUTHOR

Copyright 2008, Paul Fenwick E<lt>pjf@perltraining.com.auE<gt>

=head1 LICENSE

This module is free software.  You may distribute it under the
same terms as Perl itself.

=head1 SEE ALSO

L<Fatal>, L<autodie::exception>, L<IPC::System::Simple>

=head1 ACKNOWLEDGEMENTS

Mark Reed and Roland Giersig -- Klingon translators.

See the F<AUTHORS> file for full credits.  The latest version of this
file can be found at
L<http://github.com/pfenwick/autodie/tree/AUTHORS> .

=cut
