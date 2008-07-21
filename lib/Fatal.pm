package Fatal;

use 5.008;  # 5.8.x needed for autodie
use Carp;
use strict;
use warnings;

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

# Older versions of IPC::System::Simple don't support all the
# features we need.

use constant MIN_IPC_SYS_SIMPLE_VER => 0.12;

# All the Fatal/autodie modules share the same version number.
our $VERSION = "1.99";

our $Debug ||= 0;

# We have some tags that can be passed in for use with import.
# These are all assumed to be CORE::

my %TAGS = (
    ':io'      => [qw(:file :filesys :socket)],
    ':file'    => [qw(open close sysopen fcntl fileno)],
    ':filesys' => [qw(opendir)],
    ':threads' => [qw(fork)],
    ':system'  => [qw(system exec)],

    # Can we use qw(getpeername getsockname)? What do they do on failure?
    # XXX - Can socket return false?
    ':socket'  => [qw(accept bind connect getsockopt listen recv send
                   setsockopt shutdown socketpair)],

    # Our defaults don't include system(), because it depends upon
    # an optional module, and it breaks the exotic form.
    #
    # This *may* change in the future.  I'd love IPC::System::Simple
    # to be a dependency rather than a recommendation, and hence for
    # system() to be autodying by default.

    ':default' => [qw(:io :threads)],
);

$TAGS{':all'}  = [ keys %TAGS ];

# This hash contains subroutines for which we should
# subroutine() // die() rather than subroutine() || die()

my %Use_defined_or;

# CORE::open returns undef on failure.  It can legitimately return
# 0 on success, eg: open(my $fh, '-|') || exec(...);

@Use_defined_or{qw(
    CORE::fork
    CORE::recv
    CORE::send
    CORE::open
    CORE::fileno
)} = ();

# Cached_fatalised_sub caches the various versions of our
# fatalised subs as they're produced.  This means we don't
# have to build our own replacement of CORE::open and friends
# for every single package that wants to use them.

my %Cached_fatalised_sub = ();

# Every time we're called with package scope, we record the subroutine
# (including package or CORE::) in %Package_Fatal.  This allows us
# to detect illegal combinations of autodie and Fatal, and makes sure
# we don't accidently make a Fatal function autodying (which isn't
# very useful).

my %Package_Fatal = ();

# The first time we're called with a user-sub, we cache it here.
# In the case of a "no autodie ..." we put back the cached copy.

my %Original_user_sub = ();

# We use our package in a few hash-keys.  Having it in a scalar is
# convenient.  The "guard $PACKAGE" string is used as a key when
# setting up lexical guards.

my $PACKAGE       = __PACKAGE__;
my $PACKAGE_GUARD = "guard $PACKAGE";
my $NO_PACKAGE    = "no $PACKAGE";      # Used to detect 'no autodie'

# Here's where all the magic happens when someone write 'use Fatal'
# or 'use autodie'.

sub import {
    my $class   = shift(@_);
    my $void    = 0;
    my $lexical = 0;

    my ($pkg, $filename) = caller();

    @_ or return;   # 'use Fatal' is a no-op.

    # If we see the :lexical flag, then _all_ arguments are
    # changed lexically

    if ($_[0] eq LEXICAL_TAG) {
        $lexical = 1;
        shift @_;

        # If we see no arguments and :lexical, we assume they
        # wanted ':default'.

        if (@_ == 0) {
            push(@_, ':default');
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

    # Thiese subs will get unloaded at the end of lexical scope.
    my %unload_later;

    # This hash helps us track if we've alredy done work.
    my %done_this;

    # NB: we're using while/shift rather than foreach, since
    # we'll be modifying the array as we walk through it.

    while (my $func = shift @fatalise_these) {

        if ($func eq VOID_TAG) {

            # When we see :void, set the void flag.
            $void = 1;

        } elsif (exists $TAGS{$func}) {

            # When it's a tag, expand it.
            push(@fatalise_these, @{ $TAGS{$func} });

        } else {

            # Otherwise, fatalise it.

            # If we've already made something fatal this call,
            # then don't do it twice.

            next if $done_this{$func};

            # We're going to make a subroutine fatalistic.
            # However if we're being invoked with 'use Fatal qw(x)'
            # and we've already been called with 'no autodie qw(x)'
            # in the same scope, we consider this to be an error.
            # Mixing Fatal and autodie effects was considered to be
            # needlessly confusing on p5p.

            my $sub = $func;
            $sub = "${pkg}::$sub" unless $sub =~ /::/;

            # If we're being called as Fatal, and we've previously
            # had a 'no X' in scope for the subroutine, then complain
            # bitterly.

            if (! $lexical and $^H{$NO_PACKAGE}{$sub}) {
                 croak(sprintf(ERROR_FATAL_CONFLICT, $func, $func));
            }

            # We're not being used in a confusing way, so make
            # the sub fatal.  Note that _make_fatal returns the
            # old (original) version of the sub, or undef for
            # built-ins.

            my $sub_ref = $class->_make_fatal(
                $func, $pkg, $void, $lexical, $filename
            );

            $done_this{$func}++;

            $Original_user_sub{$sub} ||= $sub_ref;

            # If we're making lexical changes, we need to arrange
            # for them to be cleaned at the end of our scope, so
            # record them here.

            $unload_later{$func} = $sub_ref if $lexical;
        }
    }

    if ($lexical) {

        # Dark magic to have autodie work under 5.8
        # Copied from namespace::clean, that copied it from
        # autobox, that found it on an ancient scroll written
        # in blood.

        # This magic bit causes %^H to be lexically scoped.

        $^H |= 0x020000;

        # Our package guard gets invoked when we leave our lexical
        # scope.

        push(@ { $^H{$PACKAGE_GUARD} }, autodie::Scope::Guard->new(sub {
            $class->_install_subs($pkg, \%unload_later);
        }));

    }

    return;

}

# The code here is originally lifted from namespace::clean,
# by Robert "phaylon" Sedlacek.
#
# It's been redesigned after feedback from ikegami on perlmonks.
# See http://perlmonks.org/?node_id=693338 .  Ikegami rocks.
#
# Given a package, and hash of (subname => subref) pairs,
# we install the given subroutines into the package.  If
# a subref is undef, the subroutine is removed.  Otherwise
# it replaces any existing subs which were already there.

sub _install_subs {
    my ($class, $pkg, $subs_to_reinstate) = @_;

    my $pkg_sym = "${pkg}::";

    while(my ($sub_name, $sub_ref) = each %$subs_to_reinstate) {

        my $full_path = $pkg_sym.$sub_name;

        # Copy symbols across to temp area.

        no strict 'refs';

        local *__tmp = *{ $full_path };

        # Nuke the old glob.
        { no strict; delete $pkg_sym->{$sub_name}; }

        # Copy innocent bystanders back.

        foreach my $slot (qw( SCALAR ARRAY HASH IO FORMAT ) ) {
            next unless defined *__tmp{ $slot };
            *{ $full_path } = *__tmp{ $slot };
        }

        # Put back the old sub (if there was one).

        if ($sub_ref) {

            no strict;
            *{ $pkg_sym . $sub_name } = $sub_ref;
        }
    }

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

    my @unimport_these = @_ ? @_ : ':all';

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

        # Record 'no autodie qw($sub)' as being in effect.
        # This is to catch conflicting semantics elsewhere
        # (eg, mixing Fatal with no autodie)

        $^H{$NO_PACKAGE}{$sub} = 1;

        if (my $original_sub = $Original_user_sub{$sub}) {
            # Hey, we've got an original one of these, put it back.
            $class->_install_subs($pkg, { $symbol => $original_sub });
            next;
        }

        # We don't have an original copy of the sub, on the assumption
        # it's core (or doesn't exist), we'll just nuke it.

        $class->_install_subs($pkg,{ $symbol => undef });

    }

    return;

}

# TODO - This is rather terribly inefficient right now.

{
    my %tag_cache;

    sub _expand_tag {
        my ($class, $tag) = @_;

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

# This code is from the original Fatal.  It scares me.

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

# This generates the code that will become our fatalised subroutine.

sub write_invocation {
    my ($class, $core, $call, $name, $void, $lexical, $sub, @argvs) = @_;

    if (@argvs == 1) {        # No optional arguments

        my @argv = @{$argvs[0]};
        shift @argv;

        return $class->one_invocation($core,$call,$name,$void,$sub,! $lexical,@argv);

    } else {
        my $else = "\t";
        my (@out, @argv, $n);
        while (@argvs) {
            @argv = @{shift @argvs};
            $n = shift @argv;

            push @out, "${else}if (\@_ == $n) {\n";
            $else = "\t} els";

        push @out, $class->one_invocation($core,$call,$name,$void,$sub,! $lexical,@argv);
        }
        push @out, q[
            }
            die "Internal error: $name(\@_): Do not expect to get ", scalar \@_, " arguments";
    ];

        return join '', @out;
    }
}

sub one_invocation {
    my ($class, $core, $call, $name, $void, $sub, $back_compat, @argv) = @_;

    # If someone is calling us directly (a child class perhaps?) then
    # they could try to mix void without enabling backwards
    # compatibility.  We just don't support this at all, so we gripe
    # about it rather than doing something unwise.

    if ($void and not $back_compat) {
        Carp::confess("Internal error: :void mode not supported with $class");
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
                croak("UNIMPLEMENTED: use Fatal qw(system) not yet supported.");
            };
        }

        local $" = ', ';

        if ($void) {
            return qq/return (defined wantarray)?$call(@argv):
                   $call(@argv) || croak "Can't $name(\@_)/ .
                   ($core ? ': $!' : ', \$! is \"$!\"') . '"'
        } else {
            return qq{return $call(@argv) || croak "Can't $name(\@_)} .
                   ($core ? ': $!' : ', \$! is \"$!\"') . '"';
        }
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

                # XXX - TODO - This can't be overridden in child
                # classes!

                die autodie::exception::system->new(
                    function => q{CORE::system}, args => [ @argv ],
                    message => "\$E"
                );
            }

            return \$retval;
        };

    }


    # Should we be testing to see if our result is defined, or
    # just true?
    my $use_defined_or = exists ( $Use_defined_or{$call} );

    local $" = ', ';

    # If we're going to throw an exception, here's the code to use.
    my $die = qq{
        die $class->throw(
            function => q{$true_sub_name}, args => [ @argv ],
            pragma => q{$class}
        )
    };

    return qq{
        if (wantarray) {
            my \@results = $call(@argv);
            # If we got back nothing, or we got back a single
            # undef, we die.
            if (! \@results or (\@results == 1 and ! defined \$results[0])) {
                $die;
            };
            return \@results;
        }

        # Otherwise, we're in scalar context.
        # We're never in a void context, since we have to look
        # at the result.

        my \$result = $call(@argv);

    } . ( $use_defined_or ? qq{

        $die if not defined \$result;

        return \$result;

    } : qq{

        return \$result || $die;

    } ) ;

}

# This returns the old copy of the sub, so we can
# put it back at end of scope.

# TODO : Check to make sure prototypes are restored correctly.

# TODO: Taking a huge list of arguments is awful.  Rewriting to
#       take a hash would be lovely.

sub _make_fatal {
    my($class, $sub, $pkg, $void, $lexical, $filename) = @_;
    my($name, $code, $sref, $real_proto, $proto, $core, $call);
    my $ini = $sub;

    $sub = "${pkg}::$sub" unless $sub =~ /::/;

    # Figure if we're using lexical or package semantics and
    # twiddle the appropriate bits.

    if (not $lexical) {
        $Package_Fatal{$sub} = 1;
    }

    # TODO - We *should* be able to do skipping, since we know when
    # we've lexicalised / unlexicalised a subroutine.

    $name = $sub;
    $name =~ s/.*::// or $name =~ s/^&//;

    warn  "# _make_fatal: sub=$sub pkg=$pkg name=$name void=$void\n" if $Debug;
    croak(sprintf(ERROR_BADNAME, $class, $name)) unless $name =~ /^\w+$/;

    if (defined(&$sub)) {   # user subroutine

        # This could be something that we've fatalised that
        # was in core.

        local $@; # Don't clobber anyone else's $@

        if ( $Package_Fatal{$sub} and eval { prototype "CORE::$name" } ) {

            # Something we previously made Fatal that was core.
            # This is safe to replace with an autodying to core
            # version.

            $core  = 1;
            $call  = "CORE::$name";
            $proto = prototype $call;

            # We return our $sref from this subroutine later
            # on, indicating this subroutine should be placed
            # back when we're finished.

            $sref = \&$sub;

        } else {

            # A regular user sub, or a user sub wrapping a
            # core sub.

            $sref = \&$sub;
            $proto = prototype $sref;
            $call = '&$sref';

        }

    } elsif ($sub eq $ini && $sub !~ /^CORE::GLOBAL::/) {
        # Stray user subroutine
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

    } elsif ($name eq 'exec') {
        # Exec doesn't have a prototype.  We don't care.  This
        # breaks the exotic form with lexical scope, and gives
        # the regular form a "do or die" beaviour as expected.

        $call = 'CORE::exec';
        $name = 'exec';
        $core = 1;

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

    # NB: We must use '$sub' (the name plus package) and not
    # just '$name' (the short name) here.  Failing to do so
    # results code that's in the wrong package, and hence has
    # access to the wrong package filehandles.

    if (my $subref = $Cached_fatalised_sub{$sub}{$void}{$lexical}) {
        $class->_install_subs($pkg, { $name => $subref });
        return $sref;
    }

    $code = qq[
        sub$real_proto {
            local(\$", \$!) = (', ', 0);    # TODO - Why do we do this?
    ];

    # Don't have perl whine if exec fails, since we'll be handling
    # the exception now.
    $code .= "no warnings qw(exec);\n" if $call eq "CORE::exec";

    my @protos = fill_protos($proto);
    $code .= $class->write_invocation($core, $call, $name, $void, $lexical, $sub, @protos);
    $code .= "}\n";
    warn $code if $Debug;

    # I thought that changing package was a monumental waste of
    # time for CORE subs, since they'll always be the same.  However
    # that's not the case, since they may refer to package-based
    # filehandles (eg, with open).
    #
    # There is potential to more aggressively cache core subs
    # that we know will never want to interact with package variables
    # and filehandles.

    {
        local $@;
        no strict 'refs'; # to avoid: Can't use string (...) as a symbol ref ...
        $code = eval("package $pkg; use Carp; $code");
        Carp::confess("$@") if $@;
    }

    # Now we need to wrap our fatalised sub inside an itty bitty
    # closure, which can detect if we've leaked into another file.
    # Luckily, we only need to do this for lexical (autodie)
    # subs.  Fatal subs can leak all they want, it's considered
    # a "feature" (or at least backwards compatible).

    # TODO: Cache our leak guards!

    # TODO: This is pretty hairy code.  A lot more tests would
    # be really nice for this.

    my $leak_guard;

    if ($lexical) {

        $leak_guard = qq<
            package $pkg;

            sub$real_proto {

                # If we're called from the correct file, then use the
                # autodying code.
                goto &\$code if ((caller)[1] eq \$filename);

                # Oh bother, we've leaked into another file.  Call the
                # original code.  Note that \$sref may actually be a
                # reference to a Fatalised version of a core built-in.
                # That's okay, because Fatal *always* leaks between files.

                goto &\$sref if \$sref;
        >;


        # If we're here, it must have been a core subroutine called.
        # Warning: The following code may disturb some viewers.

        # TODO: It should be possible to combine this with
        # write invocations.

        foreach my $proto (@protos) {
            local $" = ", ";    # So @args is formatted correctly.
            my ($count, @args) = @$proto;
            $leak_guard .= qq<
                if (\@_ == $count) {
                    return $call(@args);
                }
            >;
        }

        $leak_guard .= qq< croak "Internal error in Fatal/autodie.  Leak-guard failure"; } >;

        # warn "$leak_guard\n";

        local $@;

        $leak_guard = eval $leak_guard;

        die "Internal error in $class: Leak-guard installation failure: $@" if $@;
    }

    $class->_install_subs($pkg, { $name => $leak_guard || $code });

    $Cached_fatalised_sub{$sub}{$void}{$lexical} = $leak_guard || $code;

    return $sref;

}

sub throw {
    my ($class, @args) = @_;

    require autodie::exception;
    return autodie::exception->new(@args);
}

package autodie::Scope::Guard;

# This code schedules the cleanup of subroutines at the end of
# scope.  It's directly inspired by chocolateboy's excellent
# Scope::Guard module.

sub new {
    my ($class, $handler) = @_;

    return bless $handler, $class;
}

sub DESTROY {
    my ($self) = @_;

    $self->();
}

1;

__END__

=head1 NAME

Fatal - Replace functions with equivalents which succeed or die

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
L<autodie> in preference to C<Fatal>.  L<autodie> supports lexical scoping,
throws real exception objects, and provides much nicer error messages.

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
    if (not open(my $fh, '<' '/bogotic') {
        warn "Can't open /bogotic: $!";
    }

    # not checked, so error raises an exception
    close FH;

The use of C<:void> is discouraged, as it can result in exceptions
not being thrown if you I<accidentally> call a method without
void context.  Use L<autodie> instead if you need to be able to
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

=back

=head1 BUGS

C<Fatal> clobbers the context in which a function is called and always
makes it a scalar context, except when the C<:void> tag is used.
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

L<IPC::System::Simple> for a similar idea for calls to C<system()>
and backticks.

=cut
