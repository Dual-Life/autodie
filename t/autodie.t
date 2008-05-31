#!/usr/bin/perl -w
use strict;

use constant NO_SUCH_FILE => 'this_file_had_so_better_not_be_here';

use Test::More tests => 13;

{

	use autodie qw(open);

	eval { open(my $fh, '<', NO_SUCH_FILE); };
	like($@,qr{Can't open},"autodie qw(open) in lexical scope");

	no autodie qw(open);

	eval { open(my $fh, '<', NO_SUCH_FILE); };
	is($@,"","no autodie qw(open) in lexical scope");

	use autodie qw(open);
	eval { open(my $fh, '<', NO_SUCH_FILE); };
	like($@,qr{Can't open},"autodie qw(open) in lexical scope 2");

	no autodie;	# Should turn off all autodying subs
	eval { open(my $fh, '<', NO_SUCH_FILE); };
	is($@,"","no autodie in lexical scope 2");

	# Turn our pragma on one last time, so we can verify that
	# falling out of this block reverts it back to previous
	# behaviour.
	use autodie qw(open);
	eval { open(my $fh, '<', NO_SUCH_FILE); };
	like($@,qr{Can't open},"autodie qw(open) in lexical scope 3");

}

eval { open(my $fh, '<', NO_SUCH_FILE); };
is($@,"","autodie open outside of lexical scope");

eval { autodie->import(); };
like($@, qr{Cannot use lexical autodie with no arguments}, "No bare autodie");

{
	use autodie qw(:io);

	eval { open(my $fh, '<', NO_SUCH_FILE); };
	like($@,qr{Can't open},"autodie q(:io) makes autodying open");

}

{
	package Testing_autodie;

	use constant NO_SUCH_FILE => ::NO_SUCH_FILE();

	use Fatal qw(open);

	eval { open(my $fh, '<', NO_SUCH_FILE); };
	::like($@, qr{Can't open}, "Package fatal working");

	use autodie qw(open);
	::ok(1,"use autodie allowed with Fatal");

	eval { open(my $fh, '<', NO_SUCH_FILE); };
	::like($@, qr{Can't open}, "autodie and Fatal works");

	eval " no autodie qw(open); ";

	::ok($@,"no autodie on Fataled sub an error.");

	TODO: {
		our $TODO;
		local $TODO = "unimplemented";

		no autodie qw(close);
		eval "use Fatal qw(close)";

		# XXX - This needs a better test
		::like($@, qr{.}, "Using fatal after autodie is an error.");
	}
}

