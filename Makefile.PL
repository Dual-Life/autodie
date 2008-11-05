#!/usr/bin/perl -w
use strict;
use inc::Module::Install;

name(		'autodie');

all_from(	'lib/autodie.pm');

version_from(   'lib/autodie/exception.pm');
test_requires(	'Test::More');
author(         'Paul Fenwick <pjf@cpan.org>');

include(        'Module::AutoInstall');

requires(	'perl' => '5.8.0');
recommends(     'IPC::System::Simple' => '0.12'); # For autodying system()

feature(        'Support for autodying system()',
                -default => 1,
                'IPC::System::Simple' => '0.12'
);

resources(      repository => 'http://github.com/pfenwick/autodie/tree/master');
resources(      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=autodie');
resources(      license    => 'http://dev.perl.org/licenses/');
resources(	Blog       => 'http://pjf.id.au/blog/toc.html?tag=autodie');

installdirs(    'perl');    # This overwrites a core module!

WriteAll();
