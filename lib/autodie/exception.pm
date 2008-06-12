package autodie::exception;
use 5.010;
use strict;
use warnings;
use Carp qw(croak);
use Hash::Util qw(fieldhashes);

our $DEBUG = 0;

use overload
    '~~'  => "matches",
    q{""} => "stringify"
;

our $VERSION = '1.10';

=head1 NAME

autodie::exception - Exceptions from autodying functions.

=head1 SYNOPSIS

    eval {
        use autodie;

        open(my $fh, '<', 'some_file.txt');

        ...
    };

    if (my $E = $@) {
        say "Ooops!  ",$E->caller," had problems: $@";
    }


=head1 DESCRIPTION

B<NOTE!  This is BETA code.  It is NOT the final release.  Implementation
and interface may change!>

When an L<autodie> enabled function fails, it generates an
C<autodie::exception> object.  This can be interrogated to
determine further information about the error that occured.

This document is broken into two sections; those methods that
are most useful to the end-developer, and those methods for
anyone wishing to subclass or get very familiar with
C<autodie::exception>.

=head2 Common Methods

These methods are intended to be used in the everyday dealing
of exceptions.

The following assume that the error has been copied into
a separate scalar:

    if ($E = $@) {
        ...
    }

This is not required, but is recommended in case any code
is called which may reset or alter C<$@>.

=cut

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


=head3 args

    my $array_ref = $E->args;

Provides a reference to the arguments passed to the subroutine
that died.

=cut

sub args        { return $args_of{        $_[0] } }

=head3 function

    my $sub = $E->function;

The subroutine (including package) that threw the exception.

=cut

sub function   { return $sub_of{   $_[0] } }

=head3 file

    my $file = $E->file;

The file in which the error occured (eg, C<myscript.pl> or
C<MyTest.pm>).

=cut

sub file        { return $file_of{        $_[0] } }

=head3 package

    my $package = $E->package;

The package from which the exceptional subroutine was called.

=cut

sub package     { return $package_of{     $_[0] } }

=head3 caller

    my $caller = $E->caller;

The subroutine that I<called> the exceptional code.

=cut

sub caller      { return $caller_of{ $_[0] } }

=head2 line

    my $line = $E->line;

The line in C<< $E->file >> where the exceptional code was called.

=cut

sub line        { return $line_of{        $_[0] } }

=head3 errno

    my $errno = $E->errno;

The value of C<$!> at the time when the exception occured.

B<NOTE>: This method will leave the main C<autodie::exception> class
and become part of a role in the future.  You should only call
C<errno> for exceptions where C<$!> would reasonably have been
set on failure.

=cut

# TODO: Make errno part of a role.  It doesn't make sense for
# everything.

sub errno       { return $errno_of{       $_[0] } }

=head3 matches

    if ( $e->matches('open') ) { ... }

    if ( $e ~~ 'open' ) { ... }

C<matches> is used to determine whether a
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

    my $sub = $this->function;

    if ($DEBUG) {
        my $sub2 = $this->function;
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

=head2 Advanced methods

The following methods, while usable from anywhere, are primarily
intended for developers wishing to subclass C<autodie::exception>,
write code that registers custom error messages, or otherwise
work closely with the C<autodie::exception> model.

=cut

# The table below records customer formatters.
# TODO - Should this be a package var instead?
# TODO - Should these be in a completely different file, or
#        perhaps loaded on demand?  Most formatters will never
#        get used in most programs.

my %formatter_of = (
    'CORE::close' => \&_format_close,
    'CORE::open'  => \&_format_open,
);

# Default formatter for CORE::close

sub _format_close {
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

sub _format_open {
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

=head3 register

    autodie::exception->register( 'CORE::open' => \&mysub );

The C<register> method allows for the registration of a message
handler for a given subroutine.  The full subroutine name including
the package should be used.

Registered message handlers will receive the C<autodie::exception>
object as the first parameter.

=cut

sub register {
    my ($class, $symbol, $handler) = @_;

    croak "Incorrect call to autodie::register" if @_ != 3;

    $formatter_of{$symbol} = $handler;

}


=head3 add_file_and_line

    say "Problem occured",$@->add_file_and_line;

Returns the string C< at %s line %d>, where C<%s> is replaced with
the filename, and C<%d> is replaced with the line number.

Primarily intended for use by format handlers.

=cut

# Simply produces the file and line number; intended to be added
# to the end of error messages.

sub add_file_and_line {
    my ($this) = @_;

    return sprintf(" at %s line %d", $this->file, $this->line);
}

=head3 stringify

    say "The error was: ",$@->stringify;

Formats the error as a human readable string.  Usually there's no
reason to call this directly, as it is used automatically if an
C<autodie::exception> object is ever used as a string.

Child classes can override this method to change how they're
stringified.

=cut

sub stringify {
    my ($this) = @_;

    my $call        =  $this->function;

    if ($DEBUG) {
        my $dying_pkg   = $this->package;
        my $sub   = $this->function;
        my $caller = $this->caller;
        warn "Stringifing exception for $dying_pkg :: $sub / $caller / $call\n";
    }

    # TODO - This isn't using inheritance.  Should it?
    if ( my $sub = $formatter_of{$call} ) {
        return $sub->($this) . $this->add_file_and_line;
    }

    return $this->format_default;

}

=head3 format_default

    my $error_string = $E->format_default;

This produces the default error string for the given exception,
I<without using any registered message handlers>.  It is primarily
intended to be called from a message handler when they have
been passed an exception they don't want to format.

Child classes can override this method to change how default
messages are formatted.

=cut

# TODO: This produces ugly errors.  Is there any way we can
# dig around to find the actual variable names?  I know perl 5.10
# does some dark and terrible magicks to find them for undef warnings.

sub format_default {
    my ($this) = @_;

    my $call        =  $this->function;

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

=head3 new

    my $error = autodie::exception->new(
        args => \@_,
        function => "CORE::open",
    );


Creates a new C<autodie::exception> object.  Normally called
directly from an autodying function.  The C<function> argument
is required, its the function we were trying to call that
generated the exception.  The C<args> parameter is optional.

Atrributes such as package, file, and caller are determined
automatically, and cannot be specified.

=cut

sub new {
    my ($class, @args) = @_;

    my $this = \ do { my $o };

    bless($this,$class);

    # XXX - Figure out how to cleanly ensure all our inits are
    # called.  EVERY causes our code to die because it wants to
    # stringify our objects before they're initialised, causing
    # everything to explode.

    $this->_init(@args);

    return $this;
}

sub _init {

    my ($this, %args) = @_;

    our $init_called = 1;

    my $class = ref $this;

    # TODO - This always assumes we should be using caller(2).
    # should this be made smarter (or perhaps take an optional
    # caller-number argument) to play nicely with child classes
    # and exception factories?

    my ($package, $file, $line, $sub) = CORE::caller(2);

    $package_of{    $this} = $package;
    $file_of{       $this} = $file;
    $line_of{       $this} = $line;
    $caller_of{     $this} = $sub;
    $package_of{    $this} = $package;
    $errno_of{      $this} = $!;

    $args_of{       $this} = $args{args}     || [];
    $sub_of{  $this} = $args{function} or
              croak("$class->new() called without function arg");

    return $this;

}

1;

__END__

=head1 LICENSE

Copyright (C)2008 Paul Fenwick

This is free software.  You may modify and/or redistribute this
code under the same terms as Perl 5.10 itself, or, at your option,
any later version of Perl 5.

=head1 AUTHOR

Paul Fenwick E<lt>pjf@perltraining.com.auE<gt>
