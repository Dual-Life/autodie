package autodie::exception;
use 5.010;
use strict;
use warnings;
use Carp qw(croak);
use Hash::Util qw(fieldhashes);

use overload
	'~~'  => "smart_match",
	q{""} => "stringify"
;

our $VERSION = '1.00';


# XXX - Function and subroutine are too confusing.  Fix.

fieldhashes \ my(
	%args_of,
	%file_of,
	%function_of,
	%line_of,
	%package_of,
	%subroutine_of,
);

# TODO - Add hash of error messages.
# TODO - Should this be a package var instead?

my %formatter_of = (
);

sub register {
	my ($class, $symbol, $handler) = @_;

	croak "Incorrect call to autodie::register" if @_ != 3;

	$formatter_of{$symbol} = $handler;

}

sub smart_match {
	my ($this, $that) = @_;

	# XXX - Handle references
	croak "..." if ref $that;

	return 1 if $that eq $this->function;

	# Otherwise, return false.
	return 0;
}

sub stringify {
	my ($this) = @_;

	# XXX - This isn't using inheritance.  Should it?
	if (my $sub = $formatter_of{$this->function}) {
		return $sub->($this);
	}

	# TODO - Handle user-defined errors from hash.

	# TODO - Handle default error messages.
}

sub new {
	my ($class, %args) = @_;

	my $this = \ do { my $o };

	# XXX - Check how many frames we should go back.
	my ($package, $file, $line, $sub) = caller(1);

	$package_of{   $this} = $package;
	$file_of{      $this} = $file;
	$subroutine_of{$this} = $sub;
	$package_of{   $this} = $package;
	$args_of{      $this} = $args{args}     || [];
	$function_of{  $this} = $args{function} ||
		      croak("$class->new() called without function arg");

	return $this;

}

# XXX - We've got sub (the subroutine that called us) and function
# (the user-defined subroutine that caused the error).  This is stupid.
# How about 'caller' for the subroutine?

sub args       { return $args_of{       $_[0] } }
sub file       { return $file_of{       $_[0] } }
sub function   { return $function_of{   $_[0] } }
sub package    { return $package_of{    $_[0] } }
sub subroutine { return $subroutine_of{ $_[0] } }


1;
