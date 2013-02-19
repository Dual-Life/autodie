#!/usr/bin/perl -w
use strict;
use Test::More;
use File::Spec;

if (not $ENV{AUTHOR_TESTING}) {
    plan( skip_all => 'Author test.  Set $ENV{AUTHOR_TESTING} to true to run.');
}

eval { require Test::Perl::Critic; };

if ($@) {
    plan( skip_all => 'Test::Perl::Critic required for test.');
}

Test::Perl::Critic->import();
all_critic_ok();
