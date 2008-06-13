#!/usr/bin/perl -w
use strict;

use constant NO_SUCH_FILE => "this_file_or_dir_had_better_not_exist_XYZZY";

use Test::More tests => 22;

use Fatal qw(open close :void opendir);

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
# TODO - These are all testing non-public interfaces.  Ideally they
# should be switched over to using autodie instead.

eval { Fatal->import(qw(:lexical :void)) };
like($@, qr{cannot be used with lexical}, ":void can't be used with :lexical");

eval { Fatal->import(qw(open close :lexical)) };
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

eval { Fatal->import('2+2'); };
like($@,qr{Bad subroutine name},"Can't use fatal with invalid sub names");
