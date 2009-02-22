#!/usr/bin/perl -w
use strict;
use warnings;
use autodie::hints;

use File::Copy qw(copy move cp mv);

use Test::More 'no_plan';

my $hints = "autodie::hints";

is( $hints->sub_fullname(\&copy), 'File::Copy::copy' , "Id: copy" );
is( $hints->sub_fullname(\&cp),   'File::Copy::copy' , "Id: cp"   );

is( $hints->sub_fullname(\&move), 'File::Copy::move' , "Id: move" );
is( $hints->sub_fullname(\&mv),   'File::Copy::move' , "Id: mv"   );

is( $hints->get_hints_for(\&copy), $hints->LIST_EMPTY_OR_FALSE, "Copy hints");
is( $hints->get_hints_for(\&move), $hints->LIST_EMPTY_OR_FALSE, "Move hints");

1;
