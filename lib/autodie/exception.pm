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

# TODO - Add hash of error messages.
# TODO - Should this be a package var instead?

my %formatter_of = (
	'CORE::close' => \&format_close,
);

sub format_close {
	my ($this) = @_;
	my $close_arg = $this->args->[0];

	local $! = $errno_of{$this};

	# If we've got an old-style filehandle, mention it.
	if ($close_arg and not ref $close_arg) {
		return "Can't close filehandle '$close_arg' - $!";
	}

	return "Can't close($close_arg) filehandle - $!";

}

sub register {
	my ($class, $symbol, $handler) = @_;

	croak "Incorrect call to autodie::register" if @_ != 3;

	$formatter_of{$symbol} = $handler;

}

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

sub add_file_and_line {
	my ($this) = @_;

	return " at $file_of{$this} line $line_of{$this}";
}

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

sub new {
	my ($class, %args) = @_;

	my $this = \ do { my $o };

	# XXX - Check how many frames we should go back.
	my ($package, $file, $line, $sub) = caller(1);

	$package_of{    $this} = $package;
	$file_of{       $this} = $file;
	$line_of{	$this} = $line;
	$calling_sub_of{$this} = $sub;
	$package_of{    $this} = $package;
	$errno_of{	$this} = $!;
	$args_of{       $this} = $args{args}     || [];
	$call_of{       $this} = $args{call} or
			croak("$class->new() called without call_of arg");
	$dying_sub_of{  $this} = $args{function} or
		      croak("$class->new() called without function arg");

	return bless($this,$class);

}

# XXX - We've got sub (the subroutine that called us) and function
# (the user-defined subroutine that caused the error).  This is stupid.
# How about 'caller' for the subroutine?

sub args        { return $args_of{        $_[0] } }
sub file        { return $file_of{        $_[0] } }
sub dying_sub   { return $dying_sub_of{   $_[0] } }
sub package     { return $package_of{     $_[0] } }
sub calling_sub { return $calling_sub_of{ $_[0] } }
sub line        { return $line_of{        $_[0] } }
sub call        { return $call_of{        $_[0] } }

1;
