package autodie::ScopeUtil;

use strict;
use warnings;

# Docs say that perl 5.8.3 has Exporter 5.57 and autodie requires
# 5.8.4, so this should "just work".
use Exporter 5.57 qw(import);

use autodie::Scope::Guard;

our @EXPORT_OK = qw(on_end_of_compile_scope);

# docs says we should pick __PACKAGE__ /<whatever>
my $H_KEY = __PACKAGE__ . '/guard';

sub on_end_of_compile_scope {
    my ($hook) = @_;

    # Dark magic to have autodie work under 5.8
    # Copied from namespace::clean, that copied it from
    # autobox, that found it on an ancient scroll written
    # in blood.

    # This magic bit causes %^H to be lexically scoped.
    $^H |= 0x020000;

    # Technically, this is not accurate and causes problems like
    # RT#72053.  But this is the code used in autodie for ages.
    push(@ { $^H{$H_KEY} }, autodie::Scope::Guard->new($hook));
    return;
}

1;
