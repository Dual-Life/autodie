#!/usr/bin/perl -w
use strict;

use Test::More 'no_plan';

sub mytest {
    return $_[0];
}

is(mytest(q{foo}),q{foo},"Mytest returns input");

my $return = eval { mytest(undef); };

ok(!defined($return), "mytest returns undef without autodie");
is($@,"","Mytest doesn't throw an exception without autodie");

$return = eval {
    use autodie qw(mytest);

    mytest('foo');
};

is($return,'foo',"Mytest returns input with autodie");

$return = eval {
    use autodie qw(mytest);

    mytest(undef);
};

isa_ok($@,'autodie::exception',"autodie mytest/undef throws exception");

eval {
    use autodie qw(mytest);

    {
        no autodie qw(mytest);

        mytest(undef);
    }
};

TODO: {
    local $TODO = "Bug!  no autodie doesn't work properly with user subs";

    is($@,"","no autodie can counter use autodie for user subs");
}

eval {
    mytest(undef);
};

is($@,"","No lingering failure effects");

$return = eval {
    mytest("bar");
};

is($return,"bar","No lingering return effects");
