#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use constant NO_SUCH_FILE => "this_file_had_better_not_exist";

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

    warn "\nPlease ignore the following warning, it is expected"
       if $^O eq "MSWin32";

    no warnings;

    system(NO_SUCH_FILE,1);
};

ok(! $@);

TODO: {

    local $TODO = "Non-clobbering exotic system not supported in 5.10"
       if $] >= 5.010;

    no warnings;

    eval "
	    system { NO_SUCH_FILE } 1;
    ";

    ok(! $@);
}
