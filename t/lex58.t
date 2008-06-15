#!/usr/bin/perl
use strict;
use Test::More 'no_plan';
use constant NO_SUCH_FILE => "this_file_had_better_not_exist";


eval {
    use autodie qw(open);
    diag "About to use lexical open\n";
    open(my $fh, '<', NO_SUCH_FILE);
    diag "Lexical open done\n";

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
	system(NO_SUCH_FILE,1);
};

ok(! $@);

eval {
	system { NO_SUCH_FILE } 1;
};

ok(! $@);
