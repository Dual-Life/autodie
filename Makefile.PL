#!/usr/bin/perl -w
use strict;
use inc::Module::Install;

name(		'autodie');

all_from(	'lib/autodie.pm');
version_from(   'lib/autodie/exception.pm');
test_requires(	'Test::More');

requires(	'perl' => '5.8.0');
requires(	'Scope::Guard' => 0);

recommends(	'IPC::System::Simple' => '0.12'); # For autodying system()

resources(      repository => 'http://github.com/pfenwick/autodie/tree/master');
resources(	blog => 'http://pjf.id.au/blog/toc.html?tag=autodie');

WriteAll();
