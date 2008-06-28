#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# We name our non-existant file in such a way that Win32 users know
# it's okay that we get a warning due to Perl's "call the shell
# anyway" bug.

use constant NO_SUCH_FILE => "this_warning_can_be_safely_ignored";

BEGIN {
    eval "use IPC::System::Simple";
    plan skip_all => "IPC::System::Simple required" if $@;
    plan skip_all => "IPC::System::Simple 0.12 required"
    	if $IPC::System::Simple::VERSION < 0.12;
}

plan 'no_plan';

# These tests are designed to test very basic support for
# autodie under perl 5.8.  They now work, but are left in
# useful simple tests.

eval {
    use autodie qw(open);
    open(my $fh, '<', NO_SUCH_FILE);

};
ok($@);

eval {
    open(my $fh, '<', NO_SUCH_FILE);
};

ok(! $@);


eval {
    use autodie qw(system);
    system(NO_SUCH_FILE,1);
};

ok($@);

eval {

    # Because Perl *always* calls the shell under Win32, even
    # though mutli-arg system shouldn't, we always get a warning
    # (from the shell, not perl) for the line below.
    #
    # IPC::System::Simple and autodie's system() never call the
    # shell when called with multiple arguments.

    warn "\nPlease ignore the following warning, it is expected\n"
       if $^O eq "MSWin32";

    no warnings;

    system(NO_SUCH_FILE,1);
};

ok(! $@);

{
    no warnings;  # Disables "can't exec..." warning.

    # Test exotic system.

    eval " system { NO_SUCH_FILE } 1; ";

    ok(! $@);
}
