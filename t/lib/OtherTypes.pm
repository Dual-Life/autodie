package OtherTypes;

our $foo = 23;
our @foo = "bar";
our %foo = (mouse => "trap");
open foo, "<", $0;

format foo =
foo
.

BEGIN {
    $main::pvio = *foo{IO};
    $main::pvfm = *foo{FORMAT};
}

use namespace::clean "foo";

sub foo { 1 }

1;
