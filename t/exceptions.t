#!/usr/bin/perl -w
use strict;
use Test::More;

BEGIN { plan skip_all => "Perl 5.10 only tests" if $] < 5.010; }

use 5.010;
use constant NO_SUCH_FILE => 'this_file_had_better_not_exist_xyzzy';

plan 'no_plan';

eval {
	use autodie ':io';
	open(my $fh, '<', NO_SUCH_FILE);
};

ok($@,			"Exception thrown"		        );
ok($@ ~~ 'open',	"Exception from open"		        );
ok($@ ~~ ':file',	"Exception from open / class :file"	);
ok($@ ~~ ':io',		"Exception from open / class :io"	);
ok($@ ~~ ':all',	"Exception from open / class :all"	);

like($@, qr/Can't open '\w+' for reading: /, "Prety printed open msg");
is($@->file, $0, "Correct file");
is($@->function, 'CORE::open', "Correct dying sub");
is($@->package, __PACKAGE__, "Correct package");
is($@->caller,__PACKAGE__."::__ANON__", "Correct caller");
is($@->args->[1], '<', 'Correct mode arg');
is($@->args->[2], NO_SUCH_FILE, 'Correct filename arg');

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

