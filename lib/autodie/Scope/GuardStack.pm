package autodie::Scope::GuardStack;

use strict;
use warnings;

use autodie::Scope::Guard;

my $H_KEY_STEM = __PACKAGE__ . '/guard';
my $COUNTER = 0;

# This code schedules the cleanup of subroutines at the end of
# scope.  It's directly inspired by chocolateboy's excellent
# Scope::Guard module.

sub new {
    my ($class) = @_;

    return bless([], $class);
}

sub push_hook {
    my ($self, $hook) = @_;
    my $h_key = $H_KEY_STEM . ($COUNTER++);
    my $size = @{$self};
    $^H{$h_key} = autodie::Scope::Guard->new(sub {
        $self->pop_hook while @{$self} > $size;
    });
    push(@{$self}, [$hook, $h_key]);
    return;
}

sub pop_hook {
    my ($self) = @_;
    my ($hook, $key) = @{ pop(@{$self}) };
    my $ref = delete($^H{$key});
    $hook->();
    return;
}

sub DESTROY {
    my ($self) = @_;

    $self->pop_hook while @{$self};
    return;
}

1;
