#!/usr/bin/perl -w
use strict;
use Fatal qw(open);
use Test::More tests => 2;
use constant NO_SUCH_FILE => "xyzzy_this_file_is_not_here";

eval {
    open(my $fh, '<', NO_SUCH_FILE);
};

TODO: {

    local $TODO = "Backwards compatibility not implemented";

    my $old_msg = qr{Can't open\(GLOB\(0x[0-9a-f]{8}\), <, xyzzy_this_file_is_not_here\): No such file or directory at \(eval 1\) line \d+
        main::__ANON__\('GLOB\(0x[0-9a-f]{8}\)', '<', 'xyzzy_this_file_is_not_here'\) called at backcompat.t line 8
        eval \Q{...}\E called at backcompat.t line \d+};

    like($@,$old_msg,"Backwards compat ugly messages");
    ok(!ref($@), "Exception is a string, not an object");
}
