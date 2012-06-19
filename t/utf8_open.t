#!/usr/bin/perl -w

# Test that open still honors the open pragma.

use strict;
use warnings;

use autodie;

use File::Temp;

use Test::More;

if( $] < '5.01000' ) {
    plan skip_all => "autodie does not honor the open pragma before 5.10";
}
else {
    plan "no_plan";
}

# Test with an open pragma on
{
    use open ':utf8';

    # Test the standard handles and all newly opened handles are utf8
    my $file = File::Temp->new;
    my $txt = "autodie is MËTÁŁ";

    # open for writing
    {
        open my $fh, ">", $file;

        my @layers = PerlIO::get_layers($fh);
        ok( grep(/utf8/, @layers), "open write honors open pragma" ) or diag join ", ", @layers;

        print $fh $txt;
        close $fh;
    }

    # open for reading, explicit
    {
        open my $fh, "<", $file;

        my @layers = PerlIO::get_layers($fh);
        ok( grep(/utf8/, @layers), "open read honors open pragma" ) or diag join ", ", @layers;

        is join("\n", <$fh>), $txt;
    }

    # open for reading, implicit
    {
        open my($fh), $file;

        my @layers = PerlIO::get_layers($fh);
        ok( grep(/utf8/, @layers), "open implicit read honors open pragma" ) or diag join ", ", @layers;

        is join("\n", <$fh>), $txt;
    }
}


# Test without open pragma
{
    my $file = File::Temp->new;
    open my $fh, ">", $file;

    my @layers = PerlIO::get_layers($fh);
    ok( grep(!/utf8/, @layers), "open pragma remains lexical" ) or diag join ", ", @layers;
}
