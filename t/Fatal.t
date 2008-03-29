#!/usr/bin/perl -w

use feature qw(say);

use constant NO_SUCH_FILE => "this_file_or_dir_had_better_not_exist_XYZZY";

use Test::More tests => 24;

use strict;
use Fatal qw(open close :void opendir sin);

is($Fatal::VERSION, 1.08, q{Version});

eval { open FOO, "<".NO_SUCH_FILE };	# Two arg open
like($@, qr/^Can't open/, q{Package Fatal::open});

my $foo = 'FOO';
for ('$foo', "'$foo'", "*$foo", "\\*$foo") {
    eval qq{ open $_, '<$0' };

    is($@,"", "Open using filehandle named - $_");

    like(scalar(<$foo>), qr{^#!.*/perl}, "File contents using - $_");
    eval qq{ close FOO };

    is($@,"", "Close filehandle using - $_");
}

eval { opendir FOO, NO_SUCH_FILE };
like($@, qr{^Can't open}, "Package :void Fatal::opendir");

eval { my $a = opendir FOO, NO_SUCH_FILE };
is($@, "", "Package :void Fatal::opendir in scalar context");

eval { Fatal->import(qw(print)) };
like(
	$@, qr{Cannot make the non-overridable builtin print fatal},
	"Can't override print"
);

# Lexical Tests

eval { Fatal->import(qw(:lexical :void)) };
like($@, qr{cannot be used with lexical}, ":void can't be used with :lexical");

eval { Fatal->import(qw(foo bar :lexical)) };
like($@, qr{:lexical must be used as first}, ":lexical must come first");

{
	use Fatal qw(:lexical chdir);

	eval { chdir(NO_SUCH_FILE); };
	like ($@, qr/^Can't chdir/, "Lexical fatal chdir");

	no Fatal qw(:lexical chdir);

	eval { chdir(NO_SUCH_FILE); };
	is ($@, "", "No lexical fatal chdir");

}

eval { chdir(NO_SUCH_FILE); };
is($@, "", "Lexical chdir becomes non-fatal out of scope.");

eval { Fatal->import(':lexical'); };
like($@,qr{Cannot use lexical Fatal with no arg},"Can't use bare :lexical");

eval { Fatal->import('2+2'); };
like($@,qr{Bad subroutine name},"Can't use fatal with invalid sub names");
