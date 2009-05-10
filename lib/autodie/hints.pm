package autodie::hints;

use strict;
use warnings;

=head1 NAME

autodie::hints - Provide hints about user subroutines to autodie

=head1 SYNOPSIS

   package Your::Module;

   sub AUTODIE_HINTS {
       return {
           foo => { scalar => HINTS, list => SOME_HINTS },
           bar => { scalar => HINTS, list => MORE_HINTS },
       }
   }


   # later
   use Your::Module qw(foo bar);
   use autodie      qw(:default foo bar);

   foo();         # succeeds or dies based on scalar hints
   print foo();   # succeeds or dies based on list hints

=head1 Hinting interface

C<autodie::hints> allows you to tell C<autodie> what your subroutines
return on failure.

Without hints, C<autodie> only considers the following return values as
evidence of failure:

=over

=item *

A false value, in scalar context

=item * 

An empty list, in list context

=item *

A list containing a single undef, in list context

=back

All other return values (including the list of the single zero, and the
list containing a single empty string) are considered true.  However,
real-world code isn't always that easy.  Perhaps the code you're working
with returns a string containing the word "FAIL" in it upon failure, or a
two element list containing C<(undef, "human error message")>.  To make
autodie work with these, we have the hinting interface.

=head2 Example hints

Hints may consist of scalars, array references, regular expression and
subroutine references.  You can specify different hints for how failure should
be identified in scalar and list contexts.

The most common context-specific hints are:

        # Scalar failures always return undef:
            {  scalar => undef  }

        # Scalar failures return any false value [default expectation]:
            {  scalar => sub { ! $_[0] }  }

        # Scalar failures always return zero explicitly:
            {  scalar => '0'  }

        # List failures always return empty list:
            {  list => []  }

        # List failures return C<()> or C<(undef)> [default expectation]:
            {  list => sub { ! @_ || @_ == 1 && !defined $_[0] }  }

        # List failures return C<()> or a single false value::
            {  list => sub { ! @_ || @_ == 1 && !$_[0]} }  }

        # List failures return (undef, "some string")
            {  list => sub { @_ == 2 && !defined $_[0]} }  }

        # Unsuccessful foo() returns 0 in all contexts...
        autodie::hints->set_hints_for(
            \&foo,
            {
                scalar => 0,
                list   => [0],
            }

This "in all contexts" construction is very common, and can be
abbreviated, using the 'fail' key. A C<< { fail => $val } >> hint is
simply a shortcut for C<< { scalar => $val, list => [ $val ] } >>:

        # Unsuccessful foo() returns 0 in all contexts...
        autodie::hints->set_hints_for(
            \&foo,
            {
                fail => 0
            }

        # Unsuccessful think_positive() returns negative number on failure...
        autodie::hints->set_hints_for(
            \&think_positive,
            {
                fail => sub { $_[0] < 0 }
            }

        # Unsuccessful my_system() returns non-zero on failure...
        autodie::hints->set_hints_for(
            \&my_system,
            {
                fail => sub { $_[0] != 0 }
            }

        # Unsuccessful bizarro_system() returns random value and sets $?...
        autodie::hints->set_hints_for(
            \&bizarro_system,
            {
                fail => sub { defined $? }
            }

On Perl 5.8, only simple scalars, array references, regular expressions and
subroutines are supported as hints, anything else is a compile-time error.

=head1 Setting hints directly

	package Your::Module;
	use autodie::hints;

	autodie::hints->set_hints_for(
		\&foo,
		{
			scalar => SCALAR_HINT,
			list   => LIST_HINT,
		}
	);

It is possible to pass either a subroutine reference (recommended) or a fully
qualified subroutine name as the first argument, so you can set hints on
modules that I<might> get loaded, but haven't been loaded yet.

The hints above are smart-matched against the return value from the
subroutine; a true result indicates failure, and an appropriate exception is
thrown.  Since one can smart-match against a subroutine, it's possible to do
quite complex checks for failure if needed.

The hint-setting interface is pretty verbose, and is designed as something
which might be written into sub-classes (my::company::autodie), or modules
(preferably next to the subroutines themselves). 

=head1 Auto-finding hints

	package Your::Module;

	sub AUTODIE_HINTS {
	    return {
	        foo => { scalar => HINTS, list => SOME_HINTS },
	        bar => { scalar => HINTS, list => MORE_HINTS },
	    }
	}

This allows your code to set hints without relying on C<autodie> and
C<autodie::hints>.  Thus if your end user chooses to use C<autodie> then hints
declared in this way will be found and loaded for correct error handling.

=head1 Insisting on hints

	# foo() and bar() must have their hints defined
	use autodie qw( !foo !bar baz );

	# Everything must have hints.
	use autodie qw( ! foo bar baz );

	# bar() and baz() must have their hints defined
	use autodie qw( foo ! bar baz );

It is possible for a user to insist that hints have been defined.  This is
done by prefixing each user-defined subroutine with a C<!> in the import
list.  A C<!> on its own specifies that all user-defined subroutines after
that point must have hints.

If hints are not available for the specified subroutines, this will cause a
compile-time error.

=cut

# TODO: implement fail.
# TODO: implement regular expression hints

use constant UNDEF_ONLY => undef;
use constant EMPTY_OR_UNDEF   => sub {
    ! @{$_[0]} ||
    @{$_[0]}==1 && !defined $_[0][0]
};

use constant EMPTY_ONLY => [];
use constant EMPTY_OR_FALSE => sub {
    ! @{$_[0]} ||
    @{$_[0]}==1 && !$_[0][0]
};

use constant DEFAULT_HINTS => {
    scalar => UNDEF_ONLY,
    list   => EMPTY_OR_UNDEF,
};

use constant HINTS_PROVIDER => 'autodie::hints::provider';

use base qw(Exporter);

our $DEBUG = 0;

# Only ( undef ) is a strange but possible situation for very
# badly written code.  It's not supported yet.

# TODO: Should we allow 'File::Copy::*' as a hash key?  This
# would be useful for modules which have lots of subs which
# express the same interface.

# TODO: Ugh, those sub refs look awful!  Give them proper
# names!

my %Hints = (
    'File::Copy::copy' => {
        scalar => sub { not $_[0] },
        list   => sub { @{$_[0]} == 1 and not $_[0][0] }
    },
    'File::Copy::move' => {
        scalar => sub { not $_[0] },,
        list   => sub { @{$_[0]} == 1 and not $_[0][0] }
    },
);

# Start by using Sub::Identify if it exists on this system.

eval { require Sub::Identify; Sub::Identify->import('get_code_info'); };

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

my %Hints_loaded = ();

sub load_hints {
    my ($class, $sub) = @_;

    my ($package) = ( $sub =~ /(.*)::/ );

    # TODO: What do we do if we can't find a package?

    # Do nothing if we've already tried to load hints for
    # this package.
    return if $Hints_loaded{$package}++;

    my $hints_available = 0;

    if ($package->can('DOES') and $package->DOES(HINTS_PROVIDER) ) {
        $hints_available = 1;
    }
    elsif ( $package->isa(HINTS_PROVIDER) ) {
        $hints_available = 1;
    }

    return if not $hints_available;

    my %package_hints = %{ $package->AUTODIE_HINTS };

    foreach my $sub (keys %package_hints) {

        my $hint = $package_hints{$sub};

        # Ensure we have a package name.
        $sub = "${package}::$sub" if $sub !~ /::/;

        # TODO - Currently we don't check for conflicts, should we?
        $Hints{$sub} = $hint;
    }

    return;

}

sub get_hints_for {
    my ($class, $sub) = @_;

    my $subname = $class->sub_fullname( $sub );

    # If we have hints loaded for a sub, then return them.

    if ( exists $Hints{ $subname } ) {
        return $Hints{ $subname };
    }

    # If not, we try to load them...

    $class->load_hints( $subname );

    # ...and try again!

    if ( exists $Hints{ $subname } ) {
        return $Hints{ $subname };
    }

    # It's the caller's responsibility to use defaults if desired.
    # This allows on autodie to insist on hints if needed.

    return;

}

sub set_hints_for {
    my ($class, $sub, $hints) = @_;

    if (ref $sub) {
        $sub = $class->sub_fullname( $sub );

        require Carp;

        $sub or Carp::croak("Attempts to set_hints_for unidentifiable subroutine");
    }

    if ($DEBUG) {
        warn "autodie::hints: Setting $sub to hints: $hints\n";
    }

    $Hints{ $sub } = $hints;

    return;
}

1;

__END__




=head1 Diagnostics

=head2 Attempts to set_hints_for unidentifiable subroutine

You've called C<autodie::hints->set_hints_for()> using a subroutine
reference, but that reference could not be resolved back to a
subroutine name.  It may be an anonymous subroutine (which can't
be made autodying), or may lack a name for other reasons.

If you receive this error with a subroutine that has a real name,
then you may have found a bug in autodie.  See L<autodie/BUGS>
for how to report this.

=head1 ACKNOWLEDGEMENTS

=over 

=item *

Dr Damian Conway for suggesting the hinting interface and providing the
example usage.

=item *

Jacinta Richardson for translating much of my ideas into this
documentation.

=back

=head1 AUTHOR

Copyright 2009, Paul Fenwick E<lt>pjf@perltraining.com.auE<gt>

=head1 LICENSE

This module is free software.  You may distribute it under the
same terms as Perl itself.

=head1 SEE ALSO

L<autodie>

=cut
