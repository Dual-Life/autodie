use strict;
use warnings;
use Test::More;

if (not $ENV{AUTHOR_TESTING}) {
    plan( skip_all => 'Author test.  Set $ENV{AUTHOR_TESTING} to true to run.');
}

# Ensure a recent version of Test::Pod::Coverage
my $min_tpc = 1.08;
eval "use Test::Pod::Coverage $min_tpc";
plan skip_all => "Test::Pod::Coverage $min_tpc required for testing POD coverage"
    if $@;

# Test::Pod::Coverage doesn't require a minimum Pod::Coverage version,
# but older versions don't recognize some common documentation styles
my $min_pc = 0.18;
eval "use Pod::Coverage $min_pc";
plan skip_all => "Pod::Coverage $min_pc required for testing POD coverage"
    if $@;

all_pod_coverage_ok({
	also_private => [ qr{^
            (?:
                 ERROR_\w+
                |unimport
                |fill_protos
                |one_invocation
                |write_invocation
                |throw
                |exception_class
                |AUTODIE_HINTS
                |LEXICAL_TAG
                |get_hints_for
                |load_hints
                |normalise_hints
                |sub_fullname
                |get_code_info
            )$
        }x ],
});

