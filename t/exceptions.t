#!/usr/bin/perl -w
use strict;
use 5.010;
use Test::More 'no_plan';

use constant NO_SUCH_FILE => 'this_file_had_better_not_exist_xyzzy';

eval {
	use autodie ':io';
	open(my $fh, '<', NO_SUCH_FILE);
};

ok($@,			"Exception thrown"		        );
ok($@ ~~ 'open',	"Exception from open"		        );
ok($@ ~~ ':file',	"Exception from open / class :file"	);
ok($@ ~~ ':io',		"Exception from open / class :io"	);
ok($@ ~~ ':all',	"Exception from open / class :all"	);

eval {
	close(THIS_FILEHANDLE_AINT_OPEN);
};

ok(! $@, "Close without autodie should fail silent");

eval {
	use autodie ':io';
	close(THIS_FILEHANDLE_AINT_OPEN);
};

like($@, qr{Can't close filehandle 'THIS_FILEHANDLE_AINT_OPEN'},"Nice msg from close");

ok($@,			"Exception thrown"		        );
ok($@ ~~ 'close',	"Exception from close"		        );
ok($@ ~~ ':file',	"Exception from close / class :file"	);
ok($@ ~~ ':io',		"Exception from close / class :io"	);
ok($@ ~~ ':all',	"Exception from close / class :all"	);

TODO: {
	local $TODO = "Unimplemented";
	like($@, qr{Can't open \w+ for reading}, "Pretty printed message");
	is($@->line, '???', "TODO: line number matching.");
}
is($@->file, $0, "Correct file");
