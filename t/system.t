#!/usr/bin/perl -w
use strict;

use constant NO_SUCH_FILE => 'this_file_had_so_better_not_be_here';

use Test::More;

BEGIN {

    require Fatal;

    eval { require IPC::System::Simple; };
    plan skip_all => 'IPC::System::Simple not installed' if ($@);

    if ($IPC::System::Simple::VERSION < Fatal::MIN_IPC_SYS_SIMPLE_VER()) {
	plan skip_all => 'IPC::System::Simple version is too low';
    }
}

plan tests => 8;

eval {
    use autodie qw(system);

    system($^X,'-e1');
};

ok($? == 0, "system completed successfully");

ok(!$@,"system returning 0 is considered fine.") or diag $@;

eval {
    use autodie qw(system);

    system(NO_SUCH_FILE, "foo");
};

ok($@, "Exception thrown");
isa_ok($@, "autodie::exception") or diag $@;
like($@,qr{failed to start}, "Reason for failure given");
like($@,qr{@{[NO_SUCH_FILE]}},"Failed command given");

TODO: {
    local $TODO = "Preserving exotic system not supported under 5.10"
        if $] >= 5.010;

    eval "system { \$^X} 'perl', '-e1'";
    is($@,"","Exotic system in same package not harmed");

}

package Bar;

system { $^X } 'perl','-e1';
::ok(1,"Exotic system in other package not harmed");
