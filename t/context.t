#!/usr/bin/perl -w
use strict;

use Test::More;

BEGIN {
    if ($] < 5.010) {
#	plan skip_all => "autodying user subs not yet supported under 5.8";
    }
}

plan 'no_plan';

sub list_return {
    return if @_;
    return qw(foo bar baz);
}

sub list_return2 {
    return if @_;
    return qw(foo bar baz);
}

# Returns a list presented to it, but also returns a single
# undef if given a list of a single undef.  This mimics the
# behaviour of many user-defined subs and built-ins (eg: open) that
# always return undef regardless of context.

sub list_mirror {
    return undef if (@_ == 1 and not defined $_[0]);
    return @_;

}

use Fatal qw(list_return);
use Fatal qw(:void list_return2);

my @list = list_return();

is_deeply(\@list,[qw(foo bar baz)],'fatal sub works in list context');

eval {
    my @line = list_return(1);  # Should die
};

ok($@,"List return fatalised");

### Tests where we've fatalised our function with :void ###

my @list2 = list_return2();

is_deeply(\@list2,[qw(foo bar baz)],'fatal sub works in list context');

eval {
    my @line = list_return2(1);  # Shouldn't die
};

ok(! $@,"void List return fatalised survives when non-void");

eval {
    list_return2(1);
};

ok($@,"void List return fatalised");

### autodie clobbering tests ###

TODO: {

    local $TODO = "5.8 autodie leaks user subs into whole pkg" if $] < 5.010;

    eval {
	list_mirror();
    };

    is($@, "", "No autodie, no fatality");
}

eval {
    use autodie qw(list_mirror);
    list_mirror();
};

ok($@, "Autodie fatality for empty return in void context");

TODO: {

    local $TODO = "5.8 autodie leaks user subs into whole pkg" if $] < 5.010;

    eval {
	list_mirror();
    };

    is($@, "", "No autodie, no fatality (after autodie used)");
}

eval {
    use autodie qw(list_mirror);
    list_mirror(undef);
};

ok($@, "Autodie fatality for undef return in void context");

eval {
    use autodie qw(list_mirror);
    my @list = list_mirror();
};

ok($@,"Autodie fatality for empty list return");

eval {
    use autodie qw(list_mirror);
    my @list = list_mirror(undef);
};

ok($@,"Autodie fatality for undef list return");

eval {
    use autodie qw(list_mirror);
    my @list = list_mirror("tada");
};

ok(! $@,"No Autodie fatality for defined list return");

eval {
    use autodie qw(list_mirror);
    my $single = list_mirror("tada");
};

ok(! $@,"No Autodie fatality for defined scalar return");

eval {
    use autodie qw(list_mirror);
    my $single = list_mirror(undef);
};

ok($@,"Autodie fatality for undefined scalar return");
