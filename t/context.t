#!/usr/bin/perl -w
use strict;

use Test::More 'no_plan';

sub list_return {
    return if @_;
    return qw(foo bar baz);
}

use Fatal qw(list_return);

TODO: {

    local $TODO = "Unimplemented: Fatal still clobbers context";

    my @list = list_return();

    is_deeply(\@list,[qw(foo bar baz)],'fatal sub works in list context');

}

eval {
    my @line = list_return(1);  # Should die
};

ok($@,"List return fatalised");
