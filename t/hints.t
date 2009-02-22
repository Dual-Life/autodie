#!/usr/bin/perl -w
use strict;
use warnings;
use autodie::hints;

BEGIN { *LIST_EMPTY_OR_FALSE = \&autodie::hints::LIST_EMPTY_OR_FALSE; }

use File::Copy qw(copy move cp mv);

use Test::More 'no_plan';

is( autodie::hints::sub_fullname(\&copy), 'File::Copy::copy' , "Id: copy" );
is( autodie::hints::sub_fullname(\&cp),   'File::Copy::copy' , "Id: cp"   );

is( autodie::hints::sub_fullname(\&move), 'File::Copy::move' , "Id: move" );
is( autodie::hints::sub_fullname(\&mv),   'File::Copy::move' , "Id: mv"   );

is( autodie::hints::get_hints_for(\&copy), LIST_EMPTY_OR_FALSE, "Copy hints");
is( autodie::hints::get_hints_for(\&move), LIST_EMPTY_OR_FALSE, "Move hints");

1;
