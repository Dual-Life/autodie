#!/usr/bin/perl -w
use strict;
use warnings;
use autodie::hints;

use File::Copy qw(copy move cp mv);

use Test::More 'no_plan';

use constant NO_SUCH_FILE  => "this_file_had_better_not_exist";
use constant NO_SUCH_FILE2 => "this_file_had_better_not_exist_xyzzy";

diag("Sub::Identify ", exists( $INC{'Sub/Identify.pm'} ) ? "is" : "is not",
     " loaded");

my $hints = "autodie::hints";

# Basic hinting tests

is( $hints->sub_fullname(\&copy), 'File::Copy::copy' , "Id: copy" );
is( $hints->sub_fullname(\&cp),   'File::Copy::copy' , "Id: cp"   );

is( $hints->sub_fullname(\&move), 'File::Copy::move' , "Id: move" );
is( $hints->sub_fullname(\&mv),   'File::Copy::move' , "Id: mv"   );

is( $hints->get_hints_for(\&copy), $hints->LIST_EMPTY_OR_FALSE, "Copy hints");
is( $hints->get_hints_for(\&move), $hints->LIST_EMPTY_OR_FALSE, "Move hints");

# Scalar context test

eval {
    use autodie qw(copy);

    my $scalar_context = copy(NO_SUCH_FILE, NO_SUCH_FILE2);
};

isnt("$@", "", "Copying in scalar context should throw an error.");
isa_ok($@, "autodie::exception");

# List context test.

eval {
    use autodie qw(copy);

    my @list_context = copy(NO_SUCH_FILE, NO_SUCH_FILE2);
};

isnt("$@", "", "Copying in list context should throw an error.");
isa_ok($@, "autodie::exception");

1;
