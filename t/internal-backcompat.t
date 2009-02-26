#!/usr/bin/perl -w
use strict;
use warnings;
use Fatal;
use Test::More 'no_plan';

# Tests to determine if Fatal's internal interfaces remain backwards
# compatible.

# fill_protos

my %protos = (
    '$'     => [ [ 1, '$_[0]' ] ],
    '$$'    => [ [ 2, '$_[0]', '$_[1]' ] ],
    '$$@'   => [ [ 3, '$_[0]', '$_[1]', '@_[2..$#_]' ] ],
    '\$'    => [ [ 1, '${$_[0]}' ] ],
    '\%'    => [ [ 1, '%{$_[0]}' ] ],
    '\%;$*' => [ [ 1, '%{$_[0]}' ], [ 2, '%{$_[0]}', '$_[1]' ],
                 [ 3, '%{$_[0]}', '$_[1]', '$_[2]' ] ],
);

while (my ($proto, $code) = each %protos) {
    is_deeply( [ Fatal::fill_protos($proto) ], $code, $proto);
}


# write_invocation

# one_invocation

# _make_fatal
