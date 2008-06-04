package autodie::exception;
use 5.010;
use strict;
use warnings;
use Carp qw(croak);
use Hash::Util qw(fieldhashes);

our $DEBUG = 0;

use overload
    '~~'  => "smart_match",
    q{""} => "stringify"
;

our $VERSION = '1.00';

# autodie::exception objects are inside-out constructions,
# using new 5.10 fieldhashes features.  They're based roughly
# on Exception::Class. I'd use E::C, but it's non-core.

fieldhashes \ my(
    %args_of,
    %file_of,
    %calling_sub_of,
    %line_of,
    %package_of,
    %dying_sub_of,
    %errno_of,
    %call_of,
);

# The table below records customer formatters.
# TODO - Should this be a package var instead?
# TODO - Should these be in a completely different file, or
#        perhaps loaded on demand?  Most formatters will never
#        get used in most programs.

my %formatter_of = (
    'CORE::close' => \&format_close,
    'CORE::open'  => \&format_open,
);

# Default formatter for CORE::close

sub format_close {
    my ($this) = @_;
    my $close_arg = $this->args->[0];

    local $! = $this->errno;

    # If we've got an old-style filehandle, mention it.
    if ($close_arg and not ref $close_arg) {
        return "Can't close filehandle '$close_arg': '$!'";
    }

    return "Can't close($close_arg) filehandle: '$!'";

}

# Default formatter for CORE::open

sub format_open {
    my ($this) = @_;

    my @open_args = @{$this->args};

    # We'll only handle 3 argument open for the moment.
    if (@open_args != 3) {
        return $this->format_default;
    }

    my $file = $open_args[2];

    local $! = $this->errno;

    given($open_args[1]) {
        when ('<')  { return "Can't open '$file' for reading: '$!'"    }
        when ('>')  { return "Can't open '$file' for writing: '$!'"    }
        when ('>>') { return "Can't open '$file' for appending: '$!'"  }
    }

    # Default message (for pipes and odd things)

    return "Can't open '$file' with mode '$open_args[1]': '$!'";
}

=head2 register

    autodie::exception->register( 'CORE::open' => \&mysub );

The C<register> method allows for the registration of a message
handler for a given subroutine.  The full subroutine name including
the package should be used.

=cut

sub register {
    my ($class, $symbol, $handler) = @_;

    croak "Incorrect call to autodie::register" if @_ != 3;

    $formatter_of{$symbol} = $handler;

}

# Implements the smart-match operator.  Currently considered true
# if:
#       * The dying subroutine name matches the string passed.
#       * The string passed starts with a : and the dying sub
#         is a member of that tag-group.

sub smart_match {
    my ($this, $that) = @_;

    state %cache;
    state $tags;

    # XXX - Handle references
    croak "UNIMPLEMENTED" if ref $that;

    my $sub = $this->call;

    if ($DEBUG) {
        my $sub2 = $this->dying_sub;
        warn "Smart-matching $that against $sub / $sub2\n";
    }

    # Direct subname match.
    return 1 if $that eq $sub;
    return 1 if $that !~ /:/ and "CORE::$that" eq $sub;
    return 0 if $that !~ /^:/;

    # Cached match / check tags.
    require Fatal;
    return $cache{$sub}{$that} //= (Fatal::_expand_tag($that) ~~ $sub);
}

# Simply produces the file and line number; intended to be added
# to the end of error messages.

sub add_file_and_line {
    my ($this) = @_;

    return " at $file_of{$this} line $line_of{$this}";
}

# stringify() is called whenever we try to use our exception
# as a string.

sub stringify {
    my ($this) = @_;

    # XXX - This is a horrible guessing hack to try and figure out
    # our sub name.
    my $call        =  ($this->call eq '&$sref') ? $this->dying_sub : $this->call;

    if ($DEBUG) {
        my $dying_pkg   = $this->package;
        my $dying_sub   = $this->dying_sub;
        my $calling_sub = $this->calling_sub;
        warn "Stringifing exception for $dying_pkg :: $dying_sub / $calling_sub / $call\n";
    }

    # XXX - This isn't using inheritance.  Should it?
    if ( my $sub = $formatter_of{$call} ) {
        return $sub->($this) . $this->add_file_and_line;
    }

    return $this->format_default;

}

# format_default() is our default method when we can't find any
# other formatter for our error message.
#
# TODO: This produces ugly errors.  Is there any way we can
# dig around to find the actual variable names?  I know perl 5.10
# does some dark and terrible magicks to find them for undef warnings.

sub format_default {
    my ($this) = @_;

    # XXX - This is a horrible guessing hack to try and figure out
    # our sub name.
    my $call        =  ($this->call eq '&$sref') ? $this->dying_sub : $this->call;

    local $! = $errno_of{$this};

    # TODO: This is probably a good idea for CORE, is it
    # a good idea for other subs?

    # Trim package name off dying sub for error messages.
    $call =~ s/.*:://;

    return "Can't $call(".
        join(q{, },@{$this->args()}) . "): $!" .
        $this->add_file_and_line;

    # TODO - Handle user-defined errors from hash.

    # TODO - Handle default error messages.

}

# Create our new object.  This blindly fills in details.

sub new {
    my ($class, %args) = @_;

    my $this = \ do { my $o };

    # XXX - Check how many frames we should go back.
    my ($package, $file, $line, $sub) = caller(1);

    $package_of{    $this} = $package;
    $file_of{       $this} = $file;
    $line_of{       $this} = $line;
    $calling_sub_of{$this} = $sub;
    $package_of{    $this} = $package;
    $errno_of{      $this} = $!;
    $args_of{       $this} = $args{args}     || [];
    $call_of{       $this} = $args{call} or
            croak("$class->new() called without call_of arg");
    $dying_sub_of{  $this} = $args{function} or
              croak("$class->new() called without function arg");

    return bless($this,$class);

}

# TODO: Some of these names don't match the presentation, and
# some of them could probably be made easier to understand.

sub args        { return $args_of{        $_[0] } }
sub file        { return $file_of{        $_[0] } }
sub dying_sub   { return $dying_sub_of{   $_[0] } }
sub package     { return $package_of{     $_[0] } }
sub calling_sub { return $calling_sub_of{ $_[0] } }
sub line        { return $line_of{        $_[0] } }
sub call        { return $call_of{        $_[0] } }
sub errno       { return $errno_of{       $_[0] } }

1;

__END__

=head1 AUTHOR

Paul Fenwick E<lt>pjf@perltraining.com.auE<gt>
