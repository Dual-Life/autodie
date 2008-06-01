#!/usr/bin/perl -w
use strict;
use inc::Module::Install;

name		'autodie';
all_from	'lib/autodie.pm';
test_requires	'Test::More';
requires	'perl' => '5.10.0';

WriteAll;
