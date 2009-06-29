#!/usr/bin/perl -w
use strict;
use File::Copy qw(copy);
use File::Find::Rule;
use autodie qw(:default :system copy);

my @corefiles = qw(
    Fatal.pm autodie.pm autodie/exception.pm autodie/exception/system.pm
    autodie/hints.pm
);

eval {
    mkdir("../perl/lib/autodie");
    mkdir("../perl/lib/autodie/exception");
    mkdir("../perl/t/lib/autodie");
};

foreach my $file (@corefiles) {
    print "lib/$file -> ";
    copy("lib/$file", "../perl/lib/$file");
    print "../perl/lib/$file\n";
}

system(qw(cp -v -r), glob("t/*"), qw(../perl/lib/autodie/t/));

my @non_core_tests = qw(
    boilerplate.t
    critic.t
    fork.t
    kwalitee.t
    lex58.t
    pod-coverage.t
    pod.t
    socket.t
    system.t
);

foreach my $test (@non_core_tests) {
    print "X $test\n";
    unlink("../perl/lib/autodie/t/$test");
}
