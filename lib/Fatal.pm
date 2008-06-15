package Fatal;

use 5.008;  # 5.08 needed for lexical Fatal
use Carp;
use strict;
use warnings;
use autodie::exception;
use constant PERL58 => ($] < 5.010);
use if PERL58, 'Scope::Guard';

# When one of our wrapped subroutines is called, there are
# possibilities:
#
# 1) We've been turned on for the current lexical context.
#    (Checked by a bit in $hints->{$PACKAGE}
# 2) We've been explicitly turned OFF for the lexical context.
#    (Checked by a bit in $hints->{$NO_PACKAGE}
# 3) We've been used lexically somewhere else, but we're currently
#    acting with default Perl semantics
#    (Checked by the above two being false, and NO entry in %Package_Fatal)
# 4) We're just working with package fatal semantics.
#    (Checked by (1) and (2) being false, and an entry in %Package_Fatal)

use constant LEXICAL_TAG => q{:lexical};
use constant VOID_TAG    => q{:void};

use constant ERROR_NOARGS    => 'Cannot use lexical %s with no arguments';
use constant ERROR_VOID_LEX  => VOID_TAG. 'cannot be used with lexical scope';
use constant ERROR_LEX_FIRST => LEXICAL_TAG.' must be used as first argument';
use constant ERROR_NO_LEX    => "no %s can only start with ".LEXICAL_TAG;
use constant ERROR_BADNAME   => "Bad subroutine name for %s: %s";
use constant ERROR_NOTSUB    => "%s is not a Perl subroutine";
use constant ERROR_NOT_BUILT => "%s is neither a builtin, nor a Perl subroutine";
use constant ERROR_CANT_OVERRIDE => "Cannot make the non-overridable builtin %s fatal";

use constant ERROR_NO_IPC_SYS_SIMPLE => "IPC::System::Simple required for Fatalised/autodying system()";

use constant ERROR_IPC_SYS_SIMPLE_OLD => "IPC::System::Simple version %f required for Fatalised/autodying system().  We only have version %f";

use constant ERROR_AUTODIE_CONFLICT => q{"no autodie '%s'" is not allowed while "use Fatal '%s'" is in effect};

use constant ERROR_FATAL_CONFLICT => q{"use Fatal '%s'" is not allowed while "no autodie '%s'" is in effect};

use constant MIN_IPC_SYS_SIMPLE_VER => 0.12;

# All the Fatal/autodie modules share the same version number.
our $VERSION = "1.10_05";

our $Debug ||= 0;

# We have some tags that can be passed in for use with import.
# These are all assumed to be CORE::

my %TAGS = (
    ':io'      => [qw(:file :filesys :socket)],
    ':file'    => [qw(open close)],
    ':filesys' => [qw(opendir)],
    # Can we use qw(getpeername getsockname)? What do they do on failure?
    # XXX - Can socket return false?
    ':socket'  => [qw(accept bind connect getsockopt listen recv send
                   setsockopt shutdown socketpair)],
);

$TAGS{':all'} = [ keys %TAGS ];

# This hash contains subroutines for which we should
# subroutine() // die() rather than subroutine() || die()

my %Use_defined_or;

@Use_defined_or{qw(
    CORE::send CORE::recv
)} = ();


# Every time we're asked to Fatalise a with lexical scope subroutine,
# we generate it a unique sequential ID number and store it in our
# %Hints_index using the full package name as a key (or
# CORE::$function for a core).  These indexes correspond to the
# bit-strings we store in %^H to remember which subroutines have been
# fatalised with a lexical scope.

my %Hints_index   = (); # Tracks indexes used in our %^H bitstring

# Tracks which subs have already been fatalised.  Important to
# avoid doubling up on work.  Keys are always the calling package
# name, and the fatalised sub.  Eg, 'main::open'.

my %Already_fatalised = ();

# Cached_fatalised_sub caches the various versions of our
# fatalised subs as they're produced.  This means we don't
# have to build our own replacement of CORE::open and friends
# for every single package that wants to use them.

my %Cached_fatalised_sub = ();

# Evry time we're called with package scope, we record the subroutine
# (including package or CORE::) in %Package_Fatal.  If we find ourselves
# in a Fatalised sub without any %^H hints turned on, we can use this
# to determine if we should be acting with package scope, or we've
# just fallen out of lexical context.

my %Package_Fatal = (); # Tracks Fatal with package scope

my $PACKAGE       = __PACKAGE__;
my $NO_PACKAGE    = "no $PACKAGE";
my $PACKAGE_GUARD = "guard $PACKAGE";

# Here's where all the magic happens when someone write 'use Fatal'
# or 'use autodie'.

sub import {
    my $class   = shift(@_);
    my $void    = 0;
    my $pkg     = (caller)[0];
    my $lexical = 0;

    @_ or return;   # 'use Fatal' is a no-op.

    # Make sure our hints start with a reasonable default.
    # We have to use empty-string rather than 0, because
    # ord(0) = 32+16.

    $^H{$PACKAGE}    = ( defined($^H{$PACKAGE}    ) ? $^H{$PACKAGE}    : "" );
    $^H{$NO_PACKAGE} = ( defined($^H{$NO_PACKAGE} ) ? $^H{$NO_PACKAGE} : "" );

    # If we see the :lexical flag, then _all_ arguments are
    # changed lexically

    if ($_[0] eq LEXICAL_TAG) {
        $lexical = 1;
        shift @_;

        # If we see no arguments and :lexical, we assume they
        # wanted ':all'.

        if (@_ == 0) {
            push(@_, ':all');
        }

        # Don't allow :lexical with :void, it's needlessly confusing.
        if ( grep { $_ eq VOID_TAG } @_ ) {
            croak(ERROR_VOID_LEX);
        }
    }

    if ( grep { $_ eq LEXICAL_TAG } @_ ) {
        # If we see the lexical tag as the non-first argument, complain.
        croak(ERROR_LEX_FIRST);
    }

    my @fatalise_these =  @_;

    # NB: we're using while/shift rather than foreach, since
    # we'll be modifying the array as we walk through it.

    my @made_fatal;

    while (my $func = shift @fatalise_these) {

        if ($func eq VOID_TAG) {

            # When we see :void, set the void flag.
            $void = 1;

        } elsif (exists $TAGS{$func}) {

            # When it's a tag, expand it.
            push(@fatalise_these, @{ $TAGS{$func} });

        } else {

            # Otherwise, fatalise it.

            # We're going to make a subroutine fatalistic.
            # However if we're being invoked with 'use Fatal qw(x)'
            # and we've already been called with 'no autodie qw(x)'
            # in the same scope, we consider this to be an error.
            # Mixing Fatal and autodie effects was considered to be
            # needlessly confusing in p5p.

            my $sub = $func;
            $sub = "${pkg}::$sub" unless $sub =~ /::/;

            my $index = _get_sub_index($sub);

            # If we're being called as Fatal, and we've previously
            # had a 'no X' in scope for the subroutine.

            no warnings 'uninitialized';
            if (! $lexical and vec($^H{$NO_PACKAGE}, $index, 1)) {
                croak(sprintf(ERROR_FATAL_CONFLICT, $_, $_));
            }

            # We're not being used in a confusing way, so make
            # the sub fatal.

            $class->_make_fatal($func, $pkg, $void, $lexical);

            # If we're making lexical changes, we need to arrange
            # for them to be cleaned at the end of our scope, so
            # record them here.

            push(@made_fatal,$func) if PERL58 and $lexical;
        }
    }

    if (PERL58 and $lexical) {

        # Dark magic to have autodie work under 5.8
        # Copied from namespace::clean, that copied it from
        # autodie, that found it on an ancient scroll written
        # in blood.  Honestly, I have no idea how it works.

        $^H |= 0x120000;

        # Our package guard gets invoked when we leave our lexical
        # scope.

        push(@ { $^H{$PACKAGE_GUARD} }, Scope::Guard->new(sub {
            $class->_remove_lexical_subs($pkg, @made_fatal);
        }));
    }

    return;

}

# The code here is lifted from namespace::clean,
# by Robert "phaylon" Sedlacek.

sub _remove_lexical_subs {
    my ($class, $pkg, @subs) = @_;

    foreach my $sub (@subs) {

        no strict;
        no warnings;

        # Copy symbols across to temp area.
        local *__tmp = *{ ${ "${pkg}::" }{ $sub } };

        # Nuke the old glob.
        delete ${ "${pkg}::" }{ $sub };

        # Copy innocent bystanders back.

        # XXX - We're not copying back subs that used to
        # be there (if we redefined them).  This is a
        # major bug, as it means autodie can only work
        # with core subs.
        #
        # Luckily, this should be easy to fix.  Just
        # cache what the old subs were, and replace them.

        foreach my $slot (qw( SCALAR ARRAY HASH IO FORMAT ) ) {
            next unless defined *__tmp{ $slot };
            *{ "${pkg}::$sub" } = *__tmp{ $slot };
        }
    };

    return;
}

sub unimport {
    my $class = shift;

    # Calling "no Fatal" must start with ":lexical"
    if ($_[0] ne LEXICAL_TAG) {
        croak(sprintf(ERROR_NO_LEX,$class));
    }

    shift @_;   # Remove :lexical

    my $pkg = (caller)[0];

    # If we've been called with arguments, then the developer
    # has explicitly stated 'no autodie qw(blah)',
    # in which case, we disable Fatalistic behaviour for 'blah'.

    @_ = (':all') if PERL58 and not @_;

    if (my @unimport_these = @_) {

        while (my $symbol = shift @unimport_these) {

            if ($symbol =~ /^:/) {

                # Looks like a tag!  Expand it!
                push(@unimport_these, @{ $TAGS{$symbol} });

                next;
            }

            my $sub = $symbol;
            $sub = "${pkg}::$sub" unless $sub =~ /::/;

            # If 'blah' was already enabled with Fatal (which has package
            # scope) then, this is considered an error.

            if (exists $Package_Fatal{$sub}) {
                croak(sprintf(ERROR_AUTODIE_CONFLICT,$symbol,$symbol));
            }

            # Under 5.8, we'll just nuke the sub out of
            # our namespace.

            # XXX - This isn't a great solution, since it
            # leaves it nuked.  We really want an un-nuke
            # function at the end.

            if (PERL58) {
                $class->_remove_lexical_subs($pkg,$symbol);
            }

            # Fiddle the appropriate bits to say that this
            # should not die for this lexical scope.  We do
            # this even if the sub hasn't been Fatalised yet,
            # since that may happen in a later invocation.

            my $index = _get_sub_index($sub);
            vec($^H{$PACKAGE},    $index,1) = 0;
            vec($^H{$NO_PACKAGE}, $index,1) = 1;
        }
    } else {

        # We hit this for 'no autodie', etc.  Disable all
        # lexical Fatal functionality.  NB, empty string rather
        # than zero because when passed into vec, 0 gets treated
        # like a string.

        $^H{$PACKAGE} = "";

        # Enable the "don't autodie" bits for all known functions.
        # This code may end up writing an extra byte, but we
        # don't care, since those bytes will never be looked
        # at.

        my $bytes = int(keys(%Hints_index) / 8)+1;
        $^H{$NO_PACKAGE} = "\x{ff}" x $bytes;
    }
}

# TODO - This is rather terribly inefficient right now.

{
    my %tag_cache;

    sub _expand_tag {
        my ($tag) = @_;

        if (my $cached = $tag_cache{$tag}) {
            return $cached;
        }

        if (not exists $TAGS{$tag}) {
            croak "Invalid exception class $tag";
        }

        my @to_process = @{$TAGS{$tag}};

        my @taglist = ();

        while (my $item = shift @to_process) {
            if ($item =~ /^:/) {
                push(@to_process, @{$TAGS{$item}} );
            } else {
                push(@taglist, "CORE::$item");
            }
        }

        $tag_cache{$tag} = \@taglist;

        return \@taglist;

    }

}

# Get, or generate and get, the bit-index of the given subroutine.

sub _get_sub_index {
    my ($sub) = @_;

    return $Hints_index{$sub} if defined $Hints_index{$sub};

    return $Hints_index{$sub} = keys %Hints_index;
}

sub fill_protos {
    my $proto = shift;
    my ($n, $isref, @out, @out1, $seen_semi) = -1;
    while ($proto =~ /\S/) {
        $n++;
        push(@out1,[$n,@out]) if $seen_semi;
        push(@out, $1 . "{\$_[$n]}"), next if $proto =~ s/^\s*\\([\@%\$\&])//;
        push(@out, "\$_[$n]"),        next if $proto =~ s/^\s*([_*\$&])//;
        push(@out, "\@_[$n..\$#_]"),  last if $proto =~ s/^\s*(;\s*)?\@//;
        $seen_semi = 1, $n--,         next if $proto =~ s/^\s*;//; # XXXX ????
        die "Internal error: Unknown prototype letters: \"$proto\"";
    }
    push(@out1,[$n+1,@out]);
    return @out1;
}

# Note that we don't actually call _get_sub_index in the compiled
# sub.  Instead we're looking up the appropriate value and passing
# that into vec().

# TODO: We want the code that we compile to be as fast as possible,
#       so it may be worth looking at the cost of using vec() compared
#       to doing appropriate bitwise operations on our hints.

sub write_invocation {
    my ($core, $call, $name, $void, $lexical, $sub, @argvs) = @_;

    # TODO: We have a huge hunk of duplicated code/string here.
    #       Do something so it's only mentioned once.
    #
    # TODO: We'd like to get rid of 'no warnings uninitialized'.
    #       This is here because sometimes our hints are completely
    #       empty (being in a lexical scope that's never seen our package).

    if (@argvs == 1) {        # No optional arguments

        my @argv = @{$argvs[0]};
        shift @argv;

        if (PERL58) {
            # XXX - Kludge - For lexical (plus maybe void) semantics under 5.8
            return one_invocation($core,$call,$name,$void,$sub,0,@argv);
        }

        my $out = qq[
            my \$hints = (caller(0))[10];    # Lexical hints hashref
            no warnings 'uninitialized';
            if (vec(\$hints->{'$PACKAGE'},]._get_sub_index($sub).qq[,1)) {
                  # We're using lexical semantics.
                  ].one_invocation($core,$call,$name,0,$sub,0,@argv).qq[
            } elsif (vec(\$hints->{'$NO_PACKAGE'},]._get_sub_index($sub).qq[,1)) {
                  # We're using 'no' lexical semantics.
                  return $call(].join(', ',@argv).qq[);
            } elsif (].($Package_Fatal{$sub}||0).qq[) {
                  # We're using package semantics.
                  ].one_invocation($core,$call,$name,$void,$sub,1,@argv).qq[
            }
            # Default: non-Fatal semantics
            return $call(].join(', ',@argv).qq[);
        ];
        return $out;

    } else {
        my $else = "\t";
        my (@out, @argv, $n);
        while (@argvs) {
            @argv = @{shift @argvs};
            $n = shift @argv;
            push @out, "${else}if (\@_ == $n) {\n";
            $else = "\t} els";

            if (PERL58) {
                # XXX - Kludge - For lexical (plus maybe void) semantics under 5.8
                push @out, one_invocation($core,$call,$name,$void,$sub,0,@argv);
                next;
            }

            push @out, qq[
                my \$hints = (caller(0))[10];    # Lexical hints hashref
                no warnings 'uninitialized';
                if (vec(\$hints->{'$PACKAGE'},]._get_sub_index($sub).qq[,1)) {
                      # We're using lexical semantics.
                      ].one_invocation($core,$call,$name,0,$sub,0,@argv).qq[
                } elsif (vec(\$hints->{'$NO_PACKAGE'},]._get_sub_index($sub).qq[,1)) {
                      # We're using 'no' lexical semantics.
                      return $call(].join(', ',@argv).qq[);
                } elsif (].($Package_Fatal{$sub}||0).qq[) {
                      # We're using  package semantics.
                      ].one_invocation($core,$call,$name,$void,$sub,1,@argv).qq[
                }
                # Default: non-Fatal semantics
                return $call(].join(', ',@argv).qq[);
            ];
        }
        push @out, <<EOC;
        }
        die "Internal error: $name(\@_): Do not expect to get ", scalar \@_, " arguments";
EOC
        return join '', @out;
    }
}

sub one_invocation {
    my ($core, $call, $name, $void, $sub, $back_compat, @argv) = @_;

    # XXX - Kludge back-compat on for :void in 5.8
    if (PERL58 and $void) {
        $back_compat = 1;
    }

    # If someone is calling us directly (a child class perhaps?) then
    # they could try to mix void without enabling backwards
    # compatibility.  We just don't support this at all, so we gripe
    # about it rather than doing something unwise.

    if ($void and not $back_compat) {
        Carp::confess("Internal error: :void mode not supported with autodie");
    }

    # @argv only contains the results of the in-built prototype
    # function, and is therefore safe to interpolate in the
    # code generators below.

    # TODO - The following clobbers context, but that's what the
    #        old Fatal did.  Do we care?

    if ($back_compat) {

        # TODO - Use Fatal qw(system) is not yet supported.  It should be!

        if ($call eq 'CORE::system') {
            return q{
                croak("UNIMPLEMENTED: use Fatal qw(system) not supported.");
            };
        }

        local $" = ', ';

        if ($void) {
            return qq/(defined wantarray)?$call(@argv):
                   $call(@argv) || croak "Can't $name(\@_)/ .
                   ($core ? ': $!' : ', \$! is \"$!\"') . '"'
        } else {
            return qq{$call(@argv) || croak "Can't $name(\@_)} .
                   ($core ? ': $!' : ', \$! is \"$!\"') . '"';
        }
    }

    # New autodie implementation.

    my $op = '||';

    if (exists $Use_defined_or{$call}) {
        $op = '//';
    }

    # The name of our original function is:
    #   $call if the function is CORE
    #   $sub if our function is non-CORE

    # The reason for this is that $call is what we're actualling
    # calling.  For our core functions, this is always
    # CORE::something.  However for user-defined subs, we're about to
    # replace whatever it is that we're calling; as such, we actually
    # calling a subroutine ref.

    # Unfortunately, none of this tells us the *ultimate* name.
    # For example, if I export 'copy' from File::Copy, I'd like my
    # ultimate name to be File::Copy::copy.
    #
    # TODO - Is there any way to find the ultimate name of a sub, as
    # described above?

    my $true_sub_name = $core ? $call : $sub;

    if ($call eq 'CORE::system') {

        # Leverage IPC::System::Simple if we're making an autodying
        # system.

        local $" = ", ";

        # We need to stash $@ into $E, rather than using
        # local $@ for the whole sub.  If we don't then
        # any exceptions from internal errors in autodie/Fatal
        # will mysteriously disappear before propogating
        # upwards.

        return qq{
            my \$retval;
            my \$E;


            {
                local \$@;

                eval {
                    \$retval = IPC::System::Simple::system(@argv);
                };

                \$E = \$@;
            }

            if (\$E) {
                die autodie::exception::system->new(
                    function => q{CORE::system}, args => [ @argv ],
                    message => "\$E"
                );
            }

            return \$retval;
        };

    }

    # XXX Total kludge, force operator to always be || under 5.8

    $op = '||' if $] < 5.010;

    local $" = ', ';

    return qq{
        if (wantarray) {
            my \@results = $call(@argv);
            # If we got back nothing, or we got back a single
            # undef, we die.
            if (! \@results or (\@results == 1 and ! defined \$results[0])) {
                die autodie::exception->new(
                    function => q{$true_sub_name}, args => [ @argv ]
                );
            };
            return \@results;
        }

        # Otherwise, we're in scalar context.

        return $call(@argv) $op die autodie::exception->new(
            function => q{$true_sub_name}, args => [ @argv ]
        );
    };

}

sub _make_fatal {
    my($class, $sub, $pkg, $void, $lexical) = @_;
    my($name, $code, $sref, $real_proto, $proto, $core, $call);
    my $ini = $sub;

    $sub = "${pkg}::$sub" unless $sub =~ /::/;

    # If we've already got hints for this sub, then we've
    # already Fatalised it.  So safe ourselves some effort
    # by setting our %^H hints and returning immediately.

    my $index             = _get_sub_index($sub);
    my $Already_fatalised = $Already_fatalised{$sub};

    # Figure if we're using lexical or package semantics and
    # twiddle the appropriate bits.

    if ($lexical) {
        vec($^H{$PACKAGE},    $index ,1) = 1;
        vec($^H{$NO_PACKAGE}, $index ,1) = 0;
    } else {
        $Package_Fatal{$sub} = 1;
    }

    # Return immediately if we've already fatalised our code.
    # XXX - Disabled under 5.8, since we need to instate our
    # replacement subs every time.
    return if not PERL58 and defined $Already_fatalised;

    $name = $sub;
    $name =~ s/.*::// or $name =~ s/^&//;

    warn  "# _make_fatal: sub=$sub pkg=$pkg name=$name void=$void\n" if $Debug;
    croak(sprintf(ERROR_BADNAME, $class, $name)) unless $name =~ /^\w+$/;

    if (defined(&$sub)) {   # user subroutine
        $sref = \&$sub;
        $proto = prototype $sref;
        $call = '&$sref';

    } elsif ($sub eq $ini && $sub !~ /^CORE::GLOBAL::/) {
        # Stray user subroutine
        # XXX - Should this be using $sub or $name (orig was $sub)
        croak(sprintf(ERROR_NOTSUB,$sub));

    } elsif ($name eq 'system') {

        # If we're fatalising system, then we need to load
        # helper code.

        eval {
            require IPC::System::Simple; # Only load it if we need it.
            require autodie::exception::system;
        };

        if ($@) { croak ERROR_NO_IPC_SYS_SIMPLE; }

            # Make sure we're using a recent version of ISS that actually
            # support fatalised system.
            if ($IPC::System::Simple::VERSION < MIN_IPC_SYS_SIMPLE_VER) {
                croak sprintf(
                ERROR_IPC_SYS_SIMPLE_OLD, MIN_IPC_SYS_SIMPLE_VER,
                $IPC::System::Simple::VERSION
                );
            }

        $call = 'CORE::system';
        $name = 'system';

    } else {            # CORE subroutine
        $proto = eval { prototype "CORE::$name" };
        croak(sprintf(ERROR_NOT_BUILT,$name)) if $@;
        croak(sprintf(ERROR_CANT_OVERRIDE,$name)) if not defined $proto;
        $core = 1;
        $call = "CORE::$name";
    }

    if (defined $proto) {
        $real_proto = " ($proto)";
    } else {
        $real_proto = '';
        $proto = '@';
    }

    my $true_name = $core ? $call : $sub;

    # TODO: This caching works, but I don't like using $void and
    # $lexical as keys.  In particular, I suspect our code may end up
    # wrapping already wrapped code when autodie and Fatal are used
    # together.

    unless ($code = $Cached_fatalised_sub{$true_name}{$void}{$lexical}) {
        $code = qq[
            sub$real_proto {
                local(\$", \$!) = (', ', 0);    # TODO - Why do we do this?
        ];
        my @protos = fill_protos($proto);
        $code .= write_invocation($core, $call, $name, $void, $lexical, $sub, @protos);
        $code .= "}\n";
        warn $code if $Debug;

        $Cached_fatalised_sub{$true_name}{$void}{$lexical} = $code;
    }

    # TODO: This changes into our required package, executes our
    # code, and takes a reference to the resulting sub.  It then
    # slots that sub into the GLOB table.  However this is a monumental
    # waste of time for CORE subs, since they're always going to be
    # the same (assuming same lexical/void switches) regardless of
    # the package.  It would be nice to cache these.

    {
        no strict 'refs'; # to avoid: Can't use string (...) as a symbol ref ...
        $code = eval("package $pkg; use Carp; $code");
        Carp::confess($@) if $@;
        no warnings;   # to avoid: Subroutine foo redefined ...
        *{$sub} = $code;

        # Mark the sub as fatalised.
        $Already_fatalised{$sub} = 1;
    }
}

1;

__END__

=head1 NAME

Fatal - replace functions with equivalents which succeed or die

=head1 SYNOPSIS

    use Fatal qw(open close);

    open(my $fh, "<", $filename);  # No need to check errors!

    use File::Copy qw(move);
    use Fatal qw(move);

    move($file1, $file2); # No need to check errors!

    sub juggle { . . . }
    Fatal->import('juggle');

=head1 BEST PRACTICE

B<Fatal has been obsoleted by the new L<autodie> pragma.> Please use
L<autodie> for deployment on systems with Perl 5.10 or newer.  It supports
lexical scoping, throws real exception objects, and provides much nicer
error messages.

The use of C<:void> with Fatal is discouraged.

=head1 DESCRIPTION

C<Fatal> provides a way to conveniently replace
functions which normally return a false value when they fail with
equivalents which raise exceptions if they are not successful.  This
lets you use these functions without having to test their return
values explicitly on each call.  Exceptions can be caught using
C<eval{}>.  See L<perlfunc> and L<perlvar> for details.

The do-or-die equivalents are set up simply by calling Fatal's
C<import> routine, passing it the names of the functions to be
replaced.  You may wrap both user-defined functions and overridable
CORE operators (except C<exec>, C<system>, C<print>, or any other
built-in that cannot be expressed via prototypes) in this way.

If the symbol C<:void> appears in the import list, then functions
named later in that import list raise an exception only when
these are called in void context--that is, when their return
values are ignored.  For example

    use Fatal qw/:void open close/;

    # properly checked, so no exception raised on error
    unless(open(FH, "< /bogotic") {
        warn "bogo file, dude: $!";
    }

    # not checked, so error raises an exception
    close FH;

The use of C<:void> is discouraged, as it can result in exceptions
not being thrown if you I<accidentally> call a method without
void context.  Use L<autodie> instead if you want to be able to
disable autodying/Fatal behaviour for a small block of code.

=head1 DIAGNOSTICS

=over 4

=item Bad subroutine name for Fatal: %s

You've called C<Fatal> with an argument that doesn't look like
a subroutine name, nor a switch that this version of Fatal
understands.

=item %s is not a Perl subroutine

You've asked C<Fatal> to try and replace a subroutine which does not
exist, or has not yet been defined.

=item %s is neither a builtin, nor a Perl subroutine

You've asked C<Fatal> to replace a subroutine, but it's not a Perl
built-in, and C<Fatal> couldn't find it as a regular subroutine.
It either doesn't exist or has not yet been defined.

=item Cannot make the non-overridable %s fatal

You've tried to use C<Fatal> on a Perl built-in that can't be
overridden, such as C<print> or C<system>, which means that
C<Fatal> can't help you, although some other modules might.
See the L</"SEE ALSO"> section of this documentation.

=item Internal error: %s

You've found a bug in C<Fatal>.  Please report it using
the C<perlbug> command.

=item Cannot use lexical Fatal with no arguments

You've tried to use C<use Fatal qw(:lexical)> but without supplying
a list of which subroutines should adopt the do-or-die behaviour.

=item :void cannot be used with lexical scope

The C<:void> and C<:lexical> options are mutually exclusive.  You
can't use them both in the same call to C<use Fatal>.

=item :lexical must be used as first argument

If you're going to use the C<:lexical> switch, it must be the first
option passed to C<Fatal>.  If you want to modify some subroutines
on a lexical basis, and others on a package-wide basis, simply
make two calls to C<use Fatal>.

=item no Fatal can only start with :lexical

C<no Fatal> only makes sense when disabling C<Fatal> behaviour
with lexical scope.  If you're going to use it, the first argument
must always be C<:lexical>.  Eg: C<no Fatal qw(:lexical open)>

=back

=head1 GOTCHAS

As of Fatal XXX, subroutines that normally return a list can
be Fatalised without clobbering their context.  It should be noted
that Fatal will consider the subroutine to fail if it returns
either an empty list, or a list consisting of a single undef.

=head1 BUGS

Fatal only makes changes the package(s) in which it is used, even when
changing built-in function.  Changing to a new package will cause Fatal not
to check calls to any functions for failure (unless Fatal was called there,
too).

C<Fatal> clobbers the context in which a function is called, always
making it a scalar context, except when the C<:void> tag is used.
This problem does not exist in L<autodie>.

=head1 AUTHOR

Original module by Lionel Cons (CERN).

Prototype updates by Ilya Zakharevich <ilya@math.ohio-state.edu>.

L<autodie> support, bugfixes, extended diagnostics, C<system>
support, and major overhauling by Paul Fenwick <pjf@perltraining.com.au>

=head1 LICENSE

This module is free software, you may distribute it under the
same terms as Perl itself.

=head1 SEE ALSO

L<autodie> for a nicer way to use lexical Fatal.

L<IPC::System::Simple> for a similar idea for calls to C<system()>.

=cut
