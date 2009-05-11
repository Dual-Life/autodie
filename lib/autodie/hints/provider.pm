package autodie::hints::provider;

sub AUTODIE_HINTS {
    my ($class) = @_;
    die "$class inherits from autodie::hints::provider but does not define its own AUTODIE_HINTS() method, or tries to call this method in its parent class.  Please create an AUTODIE_HINTS() method for this class, or remove its inheritance on autodie::hints::provider";

}

# Dummy package for inheritance.

1;
