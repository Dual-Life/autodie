package Hints_test;
use strict;
use warnings;

use base qw(Exporter);

our @EXPORT_OK = qw(
    fail_on_empty fail_on_false fail_on_undef
);

use autodie::hints qw(
    LIST_EMPTY_OR_UNDEF
    LIST_EMPTY_ONLY
    LIST_EMPTY_OR_FALSE
);

# Create some dummy subs that just return their arguments.

sub fail_on_empty { return @_; }
sub fail_on_false { return @_; }
sub fail_on_undef { return @_; }

# Set them to different failure modes when used with autodie.

autodie::hints->set_hints_for(\&fail_on_empty, LIST_EMPTY_ONLY);
autodie::hints->set_hints_for(\&fail_on_false, LIST_EMPTY_OR_FALSE);
autodie::hints->set_hints_for(\&fail_on_undef, LIST_EMPTY_OR_UNDEF);

1;
