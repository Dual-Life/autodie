package autodie::ScopeUtil;

use strict;
use warnings;

# Docs say that perl 5.8.3 has Exporter 5.57 and autodie requires
# 5.8.4, so this should "just work".
use Exporter 5.57 qw(import);

use autodie::Scope::GuardStack;

our @EXPORT_OK = qw(on_end_of_compile_scope);

# docs says we should pick __PACKAGE__ /<whatever>
my $H_STACK_KEY = __PACKAGE__ . '/stack';

sub on_end_of_compile_scope {
    my ($hook) = @_;

    # Dark magic to have autodie work under 5.8
    # Copied from namespace::clean, that copied it from
    # autobox, that found it on an ancient scroll written
    # in blood.

    # This magic bit causes %^H to be lexically scoped.
    $^H |= 0x020000;

    my $stack = $^H{$H_STACK_KEY};
    if (not defined($stack)) {
        $stack = autodie::Scope::GuardStack->new;
        $^H{$H_STACK_KEY} = $stack;
    }

    $stack->push_hook($hook);
    return;
}

1;
