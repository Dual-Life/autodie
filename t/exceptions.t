#!/usr/bin/perl -w
use strict;
use 5.010;
use Test::More 'no_plan';

use constant NO_SUCH_FILE => 'this_file_had_better_not_exist_xyzzy';

eval {
	use autodie ':io';
	open(my $fh, '<', NO_SUCH_FILE);
};

ok($@,			"Exception thrown"		);
ok($@ ~~ 'open',	"Exception from open"		);
ok($@ ~~ ':file',	"Exception from class :file"	);
ok($@ ~~ ':io',		"Exception from class :io"	);
ok($@ ~~ ':all',	"Exception from class :all"	);

like($@, qr{Can't open \w+ for reading}, "Pretty printed message");

is($@->file, $0, "Correct file");
is($@->line, '???', "TODO: line number matching.");
