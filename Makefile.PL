use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Fatal',
    AUTHOR              => 'Paul Fenwick <pjf@cpan.org>',
    VERSION_FROM        => 'lib/Fatal.pm',
    ABSTRACT_FROM       => 'lib/Fatal.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Fatal-*' },
);
