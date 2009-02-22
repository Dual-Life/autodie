#!/usr/bin/perl -w
use strict;
use warnings;
use autodie::hints;

use File::Copy qw(copy move cp mv);

use Test::More 'no_plan';

is( autodie::hints::sub_fullname(\&copy), 'File::Copy::copy' , "Id: copy" );
is( autodie::hints::sub_fullname(\&cp),   'File::Copy::copy' , "Id: cp"   );

is( autodie::hints::sub_fullname(\&move), 'File::Copy::move' , "Id: move" );
is( autodie::hints::sub_fullname(\&mv),   'File::Copy::move' , "Id: mv"   );

1;
