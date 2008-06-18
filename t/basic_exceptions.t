#!/usr/bin/perl -w
use strict;

use Test::More tests => 8;

use constant NO_SUCH_FILE => "this_file_had_better_not_exist";

eval {
	use autodie ':io';
	open(my $fh, '<', NO_SUCH_FILE);
};

like($@, qr/Can't open '\w+' for reading: /, "Prety printed open msg");
like($@, qr{\Q$0\E}, "Our file mention in error message");
is($@->file, $0, "Correct file");
is($@->function, 'CORE::open', "Correct dying sub");
is($@->package, __PACKAGE__, "Correct package");
is($@->caller,__PACKAGE__."::__ANON__", "Correct caller");
is($@->args->[1], '<', 'Correct mode arg');
is($@->args->[2], NO_SUCH_FILE, 'Correct filename arg');

