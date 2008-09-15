#!/usr/bin/perl -w
use strict;

use Test::More;
use File::Temp qw(tempfile);
use IO::Handle;

my $tmpfh = tempfile();

eval {
    truncate($tmpfh, 0);
};

if ($@) {
    plan skip_all => 'Truncate not implemented on this system';
}

plan tests => 3;

eval {
    use autodie;
    truncate(STDOUT,0);
};

isa_ok($@, 'autodie::exception', "Truncating STDOUT should throw an exception");

eval {
    use autodie;
    truncate(FOO, 0);
};

isa_ok($@, 'autodie::exception', "Truncating an unopened file is wrong.");

$tmpfh->print("Hello World");
$tmpfh->flush;

eval {
    use autodie;
    truncate($tmpfh, 0);
};

is($@, undef, "Truncating a normal file should be fine");
