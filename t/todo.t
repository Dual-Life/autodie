#!/usr/bin/perl -w
use strict;
use Test::More 'no_plan';

TODO: {
	local $TODO = "Tests to try";

	ok(0,"Make sure send/recv are fine with 0, die on undef");
}
