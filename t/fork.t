#!/usr/bin/perl -w
use strict;
use Test::More;
use constant TESTS => 3;

BEGIN {
    eval { require BSD::Resource; BSD::Resource->import() };

    if ($@) {
        plan skip_all => "BSD::Resource required to test fork()";
    }
}

plan tests => TESTS;

# This should prevent our process from being allowed to have
# any children.

my $rlimit_success = eval { setrlimit(RLIMIT_NPROC, 0, 0); };

SKIP: {
    skip("setrlimit does not allow child limiting",TESTS)
        if not $rlimit_success;

    # This should return undef quietly, as well as testing that
    # fork is failing.
    my $retval = fork();

    # If our fork was successful, we had better skip out!
    if (defined $retval) {
        $retval or exit(0);   # The child process should just exit.
        skip("fork() still creates children after setrlimit",TESTS);
    }

    eval {
        use autodie qw(fork);

        fork();         # Should die.
    };

    if ($@) {
        ok(1, "autodying fork throws an exception");
        isa_ok($@, 'autodie::exception', '... with the correct class');
        ok($@->matches('fork'), '... which matches fork()');
    }
}
