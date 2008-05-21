#!/usr/bin/perl -w
use strict;
use inc::Module::Install;

name		'Fatal';
all_from	'lib/Fatal.pm';
test_requires	'Test::More';
requires	'perl' => '5.10.0';

WriteAll;
