package autodie::hints;

use strict;
use warnings;

=head1 NAME

autodie::hints - Provide hints about user subroutines to autodie

=cut

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

use base qw(Exporter);

our $DEBUG = 0;

# Only ( undef ) is a strange but possible situation for very
# badly written code.  It's not supported yet.

# TODO: Should we allow 'File::Copy::*' as a hash key?  This
# would be useful for modules which have lots of subs which
# express the same interface.

# XXX: Ugh, those sub refs look awful!  Give them proper
# names!

my %hints = (
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

sub get_hints_for {
    my ($class, $sub) = @_;

    my $subname = $class->sub_fullname( $sub );

    my $hints =  exists $hints{ $subname } ?
                        $hints{ $subname } :
                        DEFAULT_HINTS;

    if ($DEBUG) {
        warn "autodie::hints: Got hints for $subname: $hints\n";
    }

    return $hints;

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

    $hints{ $sub } = $hints;

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

=head1 AUTHOR

Copyright 2009, Paul Fenwick E<lt>pjf@perltraining.com.auE<gt>

=head1 LICENSE

This module is free software.  You may distribute it under the
same terms as Perl itself.

=head1 SEE ALSO

L<autodie>

=cut
