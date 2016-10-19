package Shell::Completer;

# DATE
# VERSION

use strict 'vars', 'subs';
use warnings;

our %comp_funcs = (
    _dir           => ['File', 'complete_dir'],
    _file          => ['File', 'complete_file'],
    _gid           => ['Unix', 'complete_gid'],
    _group         => ['Unix', 'complete_group'],
    _pid           => ['Unix', 'complete_pid'],
    _uid           => ['Unix', 'complete_uid'],
    _user          => ['Unix', 'complete_user'],
);

for my $f (keys %comp_funcs) {
    my $fv = $comp_funcs{$f};
    eval <<_;
sub $f {
    my \%fargs = \@_;
    require Complete::$fv->[0];
    sub {
        my \%args = \@_;
        Complete::$fv->[0]::$fv->[1](\%fargs, word => \$args{word});
    };
}
_
    die "Can't declare $f: $@" if $@;
}

use Exporter qw(import);
our @ISA = qw(Exporter);
our @EXPORT = (keys %comp_funcs, "declare_completer");

sub declare_completer {
    my %fargs = @_;

    my $shell;
    if ($ENV{COMP_SHELL}) {
        ($shell = $ENV{COMP_SHELL}) =~ s!.+/!!;
    } elsif ($ENV{COMMAND_LINE}) {
        $shell = 'tcsh';
    } elsif ($ENV{COMP_LINE}) {
        $shell = 'bash';
    } else {
        die "This script is for shell completion only\n";
    }

    my $getopt_spec = {};
    for my $o (keys %{$fargs{options}}) {
        my $ov = $fargs{options}{$o};
        if (!defined($ov)) {
            $ov = sub { undef };
        } elsif (ref($ov) eq 'ARRAY') {
            $ov = sub {
                my %args = @_;
                require Complete::Util;
                Complete::Util::complete_array_elem(
                    word => $args{word},
                    array => $ov,
                );
            };
        } elsif (ref($ov) eq 'CODE') {
            #
        } else {
            die "BUG: Handler for option '$o' must either be ".
                "an arrayref or coderef";
        }
        $getopt_spec->{$o} = $ov;
    }

    my $aspec = delete $getopt_spec->{'<>'};
    my $completion = sub {
        my %args = @_;

        my $type = $args{type};
        my $ospec = $args{ospec};

        if ($type eq 'arg' && $aspec) {
            return $aspec->(%args);
        } elsif ($type eq 'optval' && $getopt_spec->{$ospec}) {
            return $getopt_spec->{$ospec}->(%args);
        }
        undef;
    };

    my ($words, $cword);
    if ($ENV{COMP_LINE}) {
        require Complete::Bash;
        ($words,$cword) = @{ Complete::Bash::parse_cmdline(undef, undef, {truncate_current_word=>1}) };
        ($words,$cword) = @{ Complete::Bash::join_wordbreak_words($words, $cword) };
    } elsif ($ENV{COMMAND_LINE}) {
        require Complete::Tcsh;
        $shell = 'tcsh';
        ($words, $cword) = @{ Complete::Tcsh::parse_cmdline() };
    }

    require Complete::Getopt::Long;

    shift @$words; $cword--; # strip program name
    my $compres = Complete::Getopt::Long::complete_cli_arg(
        words => $words, cword => $cword, getopt_spec => $getopt_spec,
        completion => $completion,
        bundling => 1, # XXX make configurable
    );

    if ($shell eq 'bash') {
        print Complete::Bash::format_completion(
            $compres, {word=>$words->[$cword]});
    } elsif ($shell eq 'tcsh') {
        print Complete::Tcsh::format_completion($compres);
    } else {
        die "Unknown shell '$shell'";
    }

    exit 0;
}

1;
#ABSTRACT: Easily add tab completion to existing CLI program

=head1 SYNOPSIS

Suppose you have a CLI named C<empower-users> that accepts some command-line
options and arguments. To add tab completion for C<foo>, write C<_foo> as
follows:

 use Shell::Completer;
 declare_completer(
     options => {
         'help|h'     => undef,               # no completion, no option value
         'verbose!'   => undef,               #
         'on-fail=s'  => ['skip', 'die'],     # complete from a list of words
         'template=s' => _file(file_ext_filter=>['tmpl', 'html']),
                                              # complete from *.tmpl or *.html files
         '<>'         => _user(),             # complete from list of users
     },
 );

Install it (on bash):

 % complete -C _foo foo

or use L<shcompgen>.

Now you can do completion for C<foo>:

 % foo -on<tab>
 % foo --on-fail _

 % foo --on-fail <tab>
 die     skip
 % foo --on-fail s<tab>
 % foo --on-fail skip _


=head1 DESCRIPTION

B<EARLY RELEASE, EXPERIMENTAL>.

This module lets you easily add shell tab completion to an existing CLI program.


=head1 FUNCTIONS

=head2 declare_completer(%args)


=head1 COMPLETION FUNCTIONS

All these functions accept a hash argument.

=head2 _dir

Complete from directories. See L<Complete::File>'s C<complete_dir> for more
details.

=head2 _file

Complete from files. See L<Complete::File>'s C<complete_file> for more details.

=head2 _gid

Complete from list of Unix GID's. See L<Complete::Unix>'s C<complete_gid> for
more details.

=head2 _group

Complete from list of Unix group names. See L<Complete::Unix>'s
C<complete_group> for more details.

=head2 _uid

Complete from list of Unix UID's. See L<Complete::Unix>'s C<complete_uid> for
more details.

=head2 _pid

Complete from list of running PID's. See L<Complete::Unix>'s C<complete_pid> for
more details.

=head2 _user

Complete from list of Unix user names. See L<Complete::Unix>'s C<complete_user>
for more details.


=head1 TODOS AND IDEAS

Add more completion functions.

Override C<|> operator to combine answers, e.g.:

 'user|U=s' => _user() | _uid(),


=head1 SEE ALSO

L<Getopt::Long::Complete> if you want to write a CLI program that can complete
itself.

L<shcompgen> from L<App::shcompgen>.

=cut
