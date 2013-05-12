#!/usr/bin/perl
use strict;
use warnings;
use autodie;

# Load time benchmark. Courtesy Niels Thykier

use constant N => 1000;

# Pretend we are a project with a N modules that all use autodie.
my $str = join("\n", map { "package A$_;\nuse autodie;\n" } (1..N));
eval $str;
