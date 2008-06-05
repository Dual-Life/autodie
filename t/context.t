#!/usr/bin/perl -w
use strict;

use Test::More 'no_plan';

sub list_return {
    return if @_;
    return qw(foo bar baz);
}

sub list_return2 {
    return if @_;
    return qw(foo bar baz);
}

use Fatal qw(list_return);
use Fatal qw(:void list_return2);

TODO: {

    local $TODO = "Unimplemented: Fatal still clobbers context";

    my @list = list_return();

    is_deeply(\@list,[qw(foo bar baz)],'fatal sub works in list context');

}

eval {
    my @line = list_return(1);  # Should die
};

ok($@,"List return fatalised");

### Tests where we've fatalised our function with :void ###

my @list = list_return2();

is_deeply(\@list,[qw(foo bar baz)],'fatal sub works in list context');

eval {
    my @line = list_return2(1);  # Shouldn't die
};

ok(! $@,"void List return fatalised survives when non-void");

eval {
    list_return2(1);
    1;  # Needed to force previous line to void context.
};

ok($@,"void List return fatalised");

