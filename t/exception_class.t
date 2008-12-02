#!/usr/bin/perl -w
use strict;

use FindBin;
use Test::More 'no_plan';

use lib "$FindBin::Bin/lib";

use constant NO_SUCH_FILE => "this_file_had_better_not_exist_xyzzy";

### Tests with non-existent exception class.

my $open_success = eval {
    use autodie::test::missing qw(open);    # Uses non-existent exceptions
    open(my $fh, '<', NO_SUCH_FILE);
    1;
};

is($open_success,undef,"Open should fail");

isnt($@,"",'$@ should not be empty');

is(ref($@),"",'$@ should not be a reference or object');

like($@, qr/Failed to load/, '$@ should contain bad exception class msg');

#### Tests with malformed exception class.

my $open_success2 = eval {
    use autodie::test::badname qw(open);
    open(my $fh, '<', NO_SUCH_FILE);
    1;
};

is($open_success2,undef,"Open should fail");

isnt($@,"",'$@ should not be empty');

is(ref($@),"",'$@ should not be a reference or object');

TODO: {
    local $TODO = "About to be fixed in separate git commit.";

    like($@, qr/Bad exception class/, '$@ should contain bad exception class msg');

}
