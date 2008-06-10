package autodie::exception;
use 5.010;
use strict;
use warnings;
use Carp qw(croak);
use Hash::Util qw(fieldhashes);
use NEXT;	# for EVERY

our $DEBUG = 0;

use overload
    '~~'  => "matches",
    q{""} => "stringify"
;

our $VERSION = '1.00';

# autodie::exception objects are inside-out constructions,
# using new 5.10 fieldhashes features.  They're based roughly
# on Exception::Class. I'd use E::C, but it's non-core.

fieldhashes \ my(
    %args_of,
    %file_of,
    %caller_of,
    %line_of,
    %package_of,
    %sub_of,
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
# Currently only works with 3-arg open.
# TODO: Pretty printing for 2-arg (and 1-arg?) open.

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

=head2 matches

	if ( $e->matches('open') ) { ... }

	if ( $e ~~ 'open' ) { ... }

C<matches> is the recommended interface for determining if a
given exception matches a particular role.  On Perl 5.10,
using smart-match (C<~~>) with an C<autodie::exception> object
will use C<matches> underneath.

An exception is considered to match a string if:

=over 4

=item *

For a string not starting with a colon, the string exactly matches the
package and subroutine that threw the exception.  For example,
C<MyModule::log>.  If the string does not contain a package name,
C<CORE::> is assumed.

=item *

For a string that does start with a colon, if the subroutine
throwing the exception I<does> that behaviour.  For example, the
C<CORE::open> subroutine does C<:file>, C<:io>, and C<:CORE>.

=back

=cut

sub matches {
    my ($this, $that) = @_;

    state %cache;
    state $tags;

    # XXX - Handle references
    croak "UNIMPLEMENTED" if ref $that;

    my $sub = $this->call;

    if ($DEBUG) {
        my $sub2 = $this->sub;
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
    my $call        =  ($this->call eq '&$sref') ? $this->sub : $this->call;

    if ($DEBUG) {
        my $dying_pkg   = $this->package;
        my $sub   = $this->sub;
        my $caller = $this->caller;
        warn "Stringifing exception for $dying_pkg :: $sub / $caller / $call\n";
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
    my $call        =  ($this->call eq '&$sref') ? $this->sub : $this->call;

    local $! = $errno_of{$this};

    # TODO: This is probably a good idea for CORE, is it
    # a good idea for other subs?

    # Trim package name off dying sub for error messages.
    $call =~ s/.*:://;

    return "Can't $call(".
        join(q{, }, map { defined($_) ? "'$_'" : "undef" } @{$this->args()}) . "): $!" .
        $this->add_file_and_line;

    # TODO - Handle user-defined errors from hash.

    # TODO - Handle default error messages.

}

# Create our new object.  This blindly fills in details.

sub new {
    my ($class, @args) = @_;

    my $this = \ do { my $o };

    bless($this,$class);

    # XXX - Figure out how to cleanly ensure all our inits are
    # called.  EVERY causes our code to die because it overloads
    # stringification(!), causing the object to try and stringify
    # before being initialised.

    $this->_init(@args);

    return $this;
}

sub _init {

    my ($this, %args) = @_;

    our $init_called = 1;

    my $class = ref $this;

    # XXX - Check how many frames we should go back.
    my ($package, $file, $line, $sub) = caller(2);

    $package_of{    $this} = $package;
    $file_of{       $this} = $file;
    $line_of{       $this} = $line;
    $caller_of{$this} = $sub;
    $package_of{    $this} = $package;
    $errno_of{      $this} = $!;
    $args_of{       $this} = $args{args}     || [];
    $call_of{       $this} = $args{call} or
            croak("$class->new() called without call_of arg");
    $sub_of{  $this} = $args{function} or
              croak("$class->new() called without function arg");

    return $this;

}

=head2 args

	my $array_ref = $e->args;

Provides a reference to the arguments passed to the subroutine
that died.

=cut

sub args        { return $args_of{        $_[0] } }

=head2 sub

	my $sub = $e->sub;

The subroutine (including package) that threw the exception.

=cut

sub sub   { return $sub_of{   $_[0] } }

=head2 file

	my $file = $e->file;

The file in which the error occured (eg, C<myscript.pl> or
C<MyTest.pm>).

=cut

sub file        { return $file_of{        $_[0] } }

=head2 package

	my $package = $e->package;

The package from which the exceptional subroutine was called.

=cut

sub package     { return $package_of{     $_[0] } }

=head2 caller

	my $caller = $e->caller;

The subroutinet that called the exceptional code.

=cut

sub caller      { return $caller_of{ $_[0] } }

=head2 line

	my $line = $e->line;

The line in C<$e->file> where the exceptional code was called.

=cut

sub line        { return $line_of{        $_[0] } }

# call - what was actually called, as oppsed to 'sub', which is what?
# Sometimes 'call' is some rubbishy rubbish.

sub call        { return $call_of{        $_[0] } }
sub errno       { return $errno_of{       $_[0] } }

1;

__END__

=head1 AUTHOR

Paul Fenwick E<lt>pjf@perltraining.com.auE<gt>
