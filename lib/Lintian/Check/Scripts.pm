# scripts -- lintian check script -*- perl -*-
#
# This is probably the right file to add a check for the use of
# set -e in bash and sh scripts.
#
# Copyright © 1998 Richard Braakman
# Copyright © 2002 Josip Rodin
# Copyright © 2016-2019 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Scripts;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;
use List::SomeUtils qw(any none);
use POSIX qw(strftime);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);
use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};
const my $ASTERISK => q{*};
const my $DOT => q{.};
const my $COLON => q{:};
const my $DOUBLE_QUOTE => q{"};
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};
const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};
const my $NOT_EQUALS => q{!=};

const my $BAD_MAINTAINER_COMMAND_FIELDS => 5;
const my $UNVERSIONED_INTERPRETER_FIELDS => 2;
const my $VERSIONED_INTERPRETER_FIELDS => 5;
const my $MAXIMUM_LINES_ANALYZED => 54;

# This is a map of all known interpreters.  The key is the interpreter
# name (the binary invoked on the #! line).  The value is an anonymous
# array of two elements.  The first argument is the path on a Debian
# system where that interpreter would be installed.  The second
# argument is the dependency that provides that interpreter.
#
# $INTERPRETERS maps names of (unversioned) interpreters to the path
# they are installed and what package to depend on to use them.
#
has INTERPRETERS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $unversioned = $self->profile->load_data(
            'scripts/interpreters',
            qr/ \s* => \s* /msx,
            sub {
                my ($interpreter, $remainder) = @_;

                my ($folder, $prerequisites)= split(/ \s* , \s* /msx,
                    $remainder, $UNVERSIONED_INTERPRETER_FIELDS);

                $prerequisites //= $EMPTY;

                return {
                    folder => $folder,
                    prerequisites => $prerequisites
                };
            });

        return $unversioned;
    });

# The more complex case of interpreters that may have a version number.
#
# This is a hash from the base interpreter name to a list.  The base
# interpreter name may appear by itself or followed by some combination of
# dashes, digits, and periods.
#
# The list contains the following values:
#  [<path>, <dependency-relation>, <regex>, <dependency-template>, <version-list>]
#
# Their meaning is documented in Lintian's scripts/versioned-interpreters
# file, though they are ordered differently and there are a few differences
# as described below:
#
# * <regex> has been passed through qr/^<value>$/
# * If <dependency-relation> was left out, it has been substituted by the
#   interpreter.
# * The magic values of <dependency-relation> are represented as:
#   @SKIP_UNVERSIONED@ ->  undef (i.e the undefined value)
# * <version-list> has been split into a list of versions.
#   (e.g. "1.6 1.8" will be ["1.6", "1.8"])
#
# A full example is:
#
#    data:
#        lua => /usr/bin, lua([\d.]+), 'lua$1', 40 50 5.1
#
#    $VERSIONED_INTERPRETERS->value ('lua') is
#       [ '/usr/bin', 'lua', qr/^lua([\d.]+)$/, 'lua$1', ["40", "50", "5.1"] ]
#
has VERSIONED_INTERPRETERS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $versioned = $self->profile->load_data(
            'scripts/versioned-interpreters',
            qr/ \s* => \s* /msx,
            sub {
                my ($interpreter, $remainder) = @_;

                my ($folder, $regex, $template, $version_list, $prerequisites)
                  = split(/ \s* , \s* /msx,
                    $remainder, $VERSIONED_INTERPRETER_FIELDS);

                my @versions = split(/ \s+ /msx, $version_list);
                $prerequisites //= $EMPTY;

                if ($prerequisites eq '@SKIP_UNVERSIONED@') {
                    $prerequisites = undef;

                } elsif ($prerequisites =~ / @ /msx) {
                    die encode_utf8(
"Unknown magic value $prerequisites for versioned interpreter $interpreter"
                    );
                }

                return {
                    folder => $folder,
                    prerequisites => $prerequisites,
                    regex => qr/^$regex$/,
                    template => $template,
                    versions => \@versions
                };
            });

        return $versioned;
    });

# When detecting commands inside shell scripts, use this regex to match the
# beginning of the command rather than checking whether the command is at the
# beginning of a line.
my $LEADINSTR
  = '(?:(?:^|[`&;(|{])\s*|(?:if|then|do|while|!)\s+|env(?:\s+[[:alnum:]_]+=(?:\S+|\"[^"]*\"|\'[^\']*\'))*\s+)';
my $LEADIN = qr/$LEADINSTR/;

# date --date="Sat, 17 Jun 2017 20:22:36 -1000" +%s
# <https://lists.debian.org/debian-announce/2017/msg00003.html>
const my $OLDSTABLE_RELEASE_EPOCH => 1_497_766_956;

#forbidden command in maintainer scripts
has BAD_MAINTAINER_COMMANDS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data(
            'scripts/maintainer-script-bad-command',
            qr/\s*\~\~/,
            sub {
                my ($in_cat,$in_auto,$package_include_pattern,
                    $script_include_pattern,$command_pattern)
                  = split(/ \s* ~~ /msx, $_[1],$BAD_MAINTAINER_COMMAND_FIELDS);

                die encode_utf8(
                    "Syntax error in scripts/maintainer-script-bad-command: $."
                  )
                  if any { !defined }
                (
                    $in_cat,$in_auto,$package_include_pattern,
                    $script_include_pattern,$command_pattern
                );

                # trim both ends
                $in_cat =~ s/^\s+|\s+$//g;
                $in_auto =~ s/^\s+|\s+$//g;
                $package_include_pattern =~ s/^\s+|\s+$//g;
                $script_include_pattern =~ s/^\s+|\s+$//g;

                $package_include_pattern ||= '\a\Z';

                $script_include_pattern ||= $DOT . $ASTERISK;

                $command_pattern =~ s/\$[{]LEADIN[}]/$LEADINSTR/;

                return {
                    ignore_automatic_sections => !!$in_auto,
                    in_cat_string => !!$in_cat,
                    package_exclude_regex => qr/$package_include_pattern/x,
                    script_include_regex => qr/$script_include_pattern/x,
                    command_pattern => $command_pattern,
                };
            });
    });

# Appearance of one of these regexes in a maintainer script means that there
# must be a dependency (or pre-dependency) on the given package.  The tag
# reported is maintainer-script-needs-depends-on-%s, so be sure to update
# scripts.desc when adding a new rule.
my %prerequisite_by_command_pattern = (
    '\badduser\s' => 'adduser',
    '\bgconf-schemas\s' => 'gconf2',
    '\bupdate-inetd\s' =>
'update-inetd | inet-superserver | openbsd-inetd | inetutils-inetd | rlinetd | xinetd',
    '\bucf\s' => 'ucf',
    '\bupdate-xmlcatalog\s' => 'xml-core',
    '\bupdate-fonts-(?:alias|dir|scale)\s' => 'xfonts-utils',
);

my @bashism_single_quote_regexes = (
    $LEADIN . qr{echo\s+(?:-[^e\s]+\s+)?\'[^\']*(\\[abcEfnrtv0])+.*?[\']},
    # unsafe echo with backslashes
    $LEADIN . qr{source\s+[\"\']?(?:\.\/|[\/\$\w~.-])\S*},
    # should be '.', not 'source'
);

my @bashism_string_regexes = (
    qr/\$\[\w+\]/,               # arith not allowed
    qr/\$\{\w+\:\d+(?::\d+)?\}/,   # ${foo:3[:1]}
    qr/\$\{\w+(\/.+?){1,2}\}/,    # ${parm/?/pat[/str]}
    qr/\$\{\#?\w+\[[0-9\*\@]+\]\}/,# bash arrays, ${name[0|*|@]}
    qr/\$\{!\w+[\@*]\}/,                 # ${!prefix[*|@]}
    qr/\$\{!\w+\}/,              # ${!name}
    qr/(\$\(|\`)\s*\<\s*\S+\s*([\)\`])/, # $(\< foo) should be $(cat foo)
    qr/\$\{?RANDOM\}?\b/,                # $RANDOM
    qr/\$\{?(OS|MACH)TYPE\}?\b/,   # $(OS|MACH)TYPE
    qr/\$\{?HOST(TYPE|NAME)\}?\b/, # $HOST(TYPE|NAME)
    qr/\$\{?DIRSTACK\}?\b/,        # $DIRSTACK
    qr/\$\{?EUID\}?\b/,            # $EUID should be "id -u"
    qr/\$\{?UID\}?\b/,           # $UID should be "id -ru"
    qr/\$\{?SECONDS\}?\b/,       # $SECONDS
    qr/\$\{?BASH_[A-Z]+\}?\b/,     # $BASH_SOMETHING
    qr/\$\{?SHELLOPTS\}?\b/,       # $SHELLOPTS
    qr/\$\{?PIPESTATUS\}?\b/,      # $PIPESTATUS
    qr/\$\{?SHLVL\}?\b/,                 # $SHLVL
    qr/<<</,                       # <<< here string
    $LEADIN . qr/echo\s+(?:-[^e\s]+\s+)?\"[^\"]*(\\[abcEfnrtv0])+.*?[\"]/,
    # unsafe echo with backslashes
);

my @bashism_regexes = (
    qr/(?:^|\s+)function \w+(\s|\(|\Z)/,  # function is useless
    qr/(test|-o|-a)\s*[^\s]+\s+==\s/, # should be 'b = a'
    qr/\[\s+[^\]]+\s+==\s/,        # should be 'b = a'
    qr/\s(\|\&)/,                        # pipelining is not POSIX
    qr/[^\\\$]\{(?:[^\s\\\}]*?,)+[^\\\}\s]*\}/, # brace expansion
    qr/(?:^|\s+)\w+\[\d+\]=/,      # bash arrays, H[0]
    $LEADIN . qr/read\s+(?:-[a-qs-zA-Z\d-]+)/,
    # read with option other than -r
    $LEADIN . qr/read\s*(?:-\w+\s*)*(?:\".*?\"|[\'].*?[\'])?\s*(?:;|$)/,
    # read without variable
    qr/\&>/,                     # cshism
    qr/(<\&|>\&)\s*((-|\d+)[^\s;|)`&\\\\]|[^-\d\s]+)/, # should be >word 2>&1
    qr/\[\[(?!:)/,               # alternative test command
    $LEADIN . qr/select\s+\w+/,    # 'select' is not POSIX
    $LEADIN . qr/echo\s+(-n\s+)?-n?en?/,  # echo -e
    $LEADIN . qr/exec\s+-[acl]/,   # exec -c/-l/-a name
    qr/(?:^|\s+)let\s/,          # let ...
    qr/(?<![\$\(])\(\(.*\)\)/,     # '((' should be '$(('
    qr/\$\[[^][]+\]/,            # '$[' should be '$(('
    qr/(\[|test)\s+-a/,          # test with unary -a (should be -e)
    qr{/dev/(tcp|udp)},          # /dev/(tcp|udp)
    $LEADIN . qr/\w+\+=/,                # should be "VAR="${VAR}foo"
    $LEADIN . qr/suspend\s/,
    $LEADIN . qr/caller\s/,
    $LEADIN . qr/complete\s/,
    $LEADIN . qr/compgen\s/,
    $LEADIN . qr/declare\s/,
    $LEADIN . qr/typeset\s/,
    $LEADIN . qr/disown\s/,
    $LEADIN . qr/builtin\s/,
    $LEADIN . qr/set\s+-[BHT]+/,   # set -[BHT]
    $LEADIN . qr/alias\s+-p/,      # alias -p
    $LEADIN . qr/unalias\s+-a/,    # unalias -a
    $LEADIN . qr/local\s+-[a-zA-Z]+/, # local -opt
    qr/(?:^|\s+)\s*\(?\w*[^\(\w\s]+\S*?\s*\(\)\s*([\{|\(]|\Z)/,
    # function names should only contain [a-z0-9_]
    $LEADIN . qr/(push|pop)d(\s|\Z)/,   # (push|pod)d
    $LEADIN . qr/export\s+-[^p]/,  # export only takes -p as an option
    $LEADIN . qr/ulimit(\s|\Z)/,
    $LEADIN . qr/shopt(\s|\Z)/,
    $LEADIN . qr/type\s/,
    $LEADIN . qr/time\s/,
    $LEADIN . qr/dirs(\s|\Z)/,
    qr/(?:^|\s+)[<>]\(.*?\)/,      # <() process substitution
    qr/(?:^|\s+)readonly\s+-[af]/, # readonly -[af]
    $LEADIN . qr/(sh|\$\{?SHELL\}?) -[rD]/, # sh -[rD]
    $LEADIN . qr/(sh|\$\{?SHELL\}?) --\w+/, # sh --long-option
    $LEADIN . qr/(sh|\$\{?SHELL\}?) [-+]O/, # sh [-+]O
);

# no dependency for install-menu, because the menu package specifically
# says not to depend on it.
has all_prerequisites => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $all_prerequisites
          = $self->processable->relation('all')
          ->logical_and($self->processable->relation('Provides'),
            $self->processable->name);

        return $all_prerequisites;
    });

has strong_prerequisites => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $strong_prerequisites = $self->processable->relation('strong');

        return $strong_prerequisites;
    });

has x_fonts => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @x_fonts
          = grep { m{^usr/share/fonts/X11/.*\.(?:afm|pcf|pfa|pfb)(?:\.gz)?$} }
          @{$self->processable->installed->sorted_list};

        return \@x_fonts;
    });

has old_versions => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %old_versions;
        for my $entry (
            $self->processable->changelog
            ? @{$self->processable->changelog->entries}
            : ()
        ) {
            my $timestamp = $entry->Timestamp // $OLDSTABLE_RELEASE_EPOCH;
            $old_versions{$entry->Version} = $timestamp
              if $timestamp < $OLDSTABLE_RELEASE_EPOCH;
        }

        return \%old_versions;
    });

has seen_helper_commands => (is => 'rw', default => sub { {} });
has added_diversions => (is => 'rw', default => sub { {} });
has removed_diversions => (is => 'rw', default => sub { {} });

has expand_diversions => (is => 'rw', default => 0);

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    $self->hint('executable-not-elf-or-script', $item->name)
      if $item->is_executable
      && $item->file_info !~ / ^ [^,]* \b ELF \b /msx
      && !$item->is_script
      && !$item->is_hardlink
      && $item->name !~ m{^ usr(?:/X11R6)?/man/ }x
      && $item->name !~ m/ [.]exe $/x # mono convention
      && $item->name !~ m/ [.]jar $/x; # Debian Java policy 2.2

    return
      unless $item->is_script;

    # Consider /usr/src/ scripts as "documentation"
    # - packages containing /usr/src/ tend to be "-source" .debs
    #   and usually comes with overrides for most of the checks
    #   below.
    # Supposedly, they could be checked as examples, but there is
    # a risk that the scripts need substitution to be complete
    # (so, syntax checking is not as reliable).

    # no checks necessary at all for scripts in /usr/share/doc/
    # unless they are examples
    return
      if ($item->name =~ m{^usr/share/doc/} || $item->name =~ m{^usr/src/})
      && $item->name !~ m{^usr/share/doc/[^/]+/examples/};

    my $basename = basename($item->interpreter);

    # Ignore Python scripts that are shipped under dist-packages; these
    # files aren't supposed to be called as scripts.
    return
      if $basename eq 'python'
      && $item->name =~ m{^usr/lib/python3/dist-packages/};

    # allow exception for .in files that have stuff like #!@PERL@
    return
      if $item->name =~ /\.in$/
      && $item->interpreter =~ /^(\@|<\<)[A-Z_]+(\@|>\>)$/;

    my $is_absolute = ($item->interpreter =~ m{^/} || $item->calls_env);

    # As a special-exception, Policy 10.4 states that Perl scripts must use
    # /usr/bin/perl directly and not via /usr/bin/env, etc.
    $self->hint(
        'incorrect-path-for-interpreter',
        '/usr/bin/env perl != /usr/bin/perl',
        $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET
      )
      if $item->calls_env
      && $item->interpreter eq 'perl'
      && $item->name !~ m{^usr/share/doc/[^/]+/examples/};

    $self->hint(
        'example-incorrect-path-for-interpreter',
        '/usr/bin/env perl != /usr/bin/perl',
        $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET
      )
      if $item->calls_env
      && $item->interpreter eq 'perl'
      && $item->name =~ m{^usr/share/doc/[^/]+/examples/};

    # Skip files that have the #! line, but are not executable and
    # do not have an absolute path and are not in a bin/ directory
    # (/usr/bin, /bin etc).  They are probably not scripts after
    # all.
    return
      if ( $item->name !~ m{(?:bin/|etc/init\.d/)}
        && (!$item->is_file || !$item->is_executable)
        && !$is_absolute
        && $item->name !~ m{^usr/share/doc/[^/]+/examples/});

    # Example directories sometimes contain Perl libraries, and
    # some people use initial lines like #!perl or #!python to
    # provide editor hints, so skip those too if they're not
    # executable.  Be conservative here, since it's not uncommon
    # for people to both not set examples executable and not fix
    # the path and we want to warn about that.
    return
      if ( $item->name =~ /\.pm\z/
        && (!item->file || !$item->is_executable)
        && !$is_absolute
        && $item->name =~ m{^usr/share/doc/[^/]+/examples/});

    # Skip upstream source code shipped in /usr/share/cargo/registry/
    return
      if $item->name =~ m{^usr/share/cargo/registry/};

    if ($item->interpreter eq $EMPTY) {

        $self->hint('script-without-interpreter', $item->name)
          if $item->name !~ m{^usr/share/doc/[^/]+/examples/};

        $self->hint('example-script-without-interpreter', $item->name)
          if $item->name =~ m{^usr/share/doc/[^/]+/examples/};

        return;
    }

    # Either they use an absolute path or they use '/usr/bin/env interp'.
    $self->hint('interpreter-not-absolute', $item->interpreter,
        $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET)
      if !$is_absolute
      && $item->name !~ m{^usr/share/doc/[^/]+/examples/};

    $self->hint('example-interpreter-not-absolute',
        $item->interpreter,
        $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET)
      if !$is_absolute
      && $item->name =~ m{^usr/share/doc/[^/]+/examples/};

    my $bash_completion_regex= qr{^usr/share/bash-completion/completions/.*};

    $self->hint('script-not-executable', $item->name)
      if (!$item->is_file || !$item->is_executable)
      && $item->name !~ m{^usr/(?:lib|share)/.*\.pm}
      && $item->name !~ m{^usr/(?:lib|share)/.*\.py}
      && $item->name !~ m{^usr/(?:lib|share)/ruby/.*\.rb}
      && $item->name !~ m{^usr/share/debconf/confmodule(?:\.sh)?$}
      && $item->name !~ /\.in$/
      && $item->name !~ /\.erb$/
      && $item->name !~ /\.ex$/
      && $item->name ne 'etc/init.d/skeleton'
      && $item->name !~ m{^etc/menu-methods}
      && $item->name !~ $bash_completion_regex
      && $item->name !~ m{^etc/X11/Xsession\.d}
      && $item->name !~ m{^usr/share/doc/}
      && $item->name !~ m{^usr/src/};

    # for bash completion issue this instead
    $self->hint('bash-completion-with-hashbang',
        $item->name,
        $LEFT_PARENTHESIS . $item->interpreter . $RIGHT_PARENTHESIS)
      if $item->name =~ $bash_completion_regex;

    # Warn about csh scripts.
    $self->hint('csh-considered-harmful', $item->name,
        $LEFT_PARENTHESIS . $item->interpreter . $RIGHT_PARENTHESIS)
      if ($basename eq 'csh' || $basename eq 'tcsh')
      && $item->is_file
      && $item->is_executable
      && $item->name !~ m{^etc/csh/login\.d/}
      && $item->name !~ m{^usr/share/doc/}
      && $item->name !~ m{^usr/src/};

    return
      unless $item->is_open_ok;

    # Syntax-check most shell scripts, but don't syntax-check
    # scripts that end in .dpatch.  bash -n doesn't stop checking
    # at exit 0 and goes on to blow up on the patch itself.
    # exclude some shells. zsh -n is broken, see #485885
    if (   $item->is_shell_script
        && $basename !~ m{^ (?: z | t?c ) sh $}x
        && !script_looks_dangerous($item)
        && -x $item->interpreter) {

  # Given an interpreter and a file, run the interpreter on that file with the
  # -n option to check syntax, discarding output and returning the exit status.
        safe_qx($item->interpreter, '-n', $item->unpacked_path);
        my $failed = $?;

        $self->hint('shell-script-fails-syntax-check',$item->name)
          if $failed
          && $item->name !~ m{^usr/share/doc/[^/]+/examples/}
          && $item->name !~ /\.dpatch$/
          && $item->name !~ /\.erb$/;

        $self->hint('example-shell-script-fails-syntax-check',$item->name)
          if $failed
          && $item->name =~ m{^usr/share/doc/[^/]+/examples/}
          && $item->name !~ /\.dpatch$/
          && $item->name !~ /\.erb$/;
    }

    # Try to find the expected path of the script to check.  First
    # check $INTERPRETERS and %versioned_interpreters.  If not
    # found there, see if it ends in a version number and the base
    # is found in $VERSIONED_INTERPRETERS
    my $interpreter_data = $self->INTERPRETERS->value($basename);

    my $versioned = 0;
    unless (defined $interpreter_data) {

        $interpreter_data = $self->VERSIONED_INTERPRETERS->value($basename);

        if (!defined $interpreter_data && $basename =~ /^(.*[^\d.-])-?[\d.]+$/)
        {
            $interpreter_data = $self->VERSIONED_INTERPRETERS->value($1);
            undef $interpreter_data
              unless $interpreter_data
              && $basename =~ /$interpreter_data->{regex}/;
        }

        $versioned = 1
          if defined $interpreter_data;
    }

    if (defined $interpreter_data) {
        my $expected = $interpreter_data->{folder} . $SLASH . $basename;

        my $context
          = $item->interpreter
          . $SPACE
          . $NOT_EQUALS
          . $SPACE
          . $expected
          . $SPACE
          . $LEFT_SQUARE_BRACKET
          . $item->name
          . $RIGHT_SQUARE_BRACKET;

        $self->hint('wrong-path-for-interpreter', $context)
          if $item->interpreter ne $expected
          && !$item->calls_env
          && $expected ne '/usr/bin/env perl'
          && $item->name !~ m{^usr/share/doc/[^/]+/examples/};

        $self->hint('example-wrong-path-for-interpreter', $context)
          if $item->interpreter ne $expected
          && !$item->calls_env
          && $expected ne '/usr/bin/env perl'
          && $item->name =~ m{^usr/share/doc/[^/]+/examples/};

        $self->hint('incorrect-path-for-interpreter', $context)
          if $item->interpreter ne $expected
          && !$item->calls_env
          && $expected eq '/usr/bin/env perl'
          && $item->name !~ m{^usr/share/doc/[^/]+/examples/};

        $self->hint('example-incorrect-path-for-interpreter', $context)
          if $item->interpreter ne $expected
          && !$item->calls_env
          && $expected eq '/usr/bin/env perl'
          && $item->name =~ m{^usr/share/doc/[^/]+/examples/};

    } elsif ($item->interpreter =~ m{^/usr/local/}) {

        $self->hint('interpreter-in-usr-local', $item->interpreter,
            $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET)
          if $item->name !~ m{^usr/share/doc/[^/]+/examples/};

        $self->hint('example-interpreter-in-usr-local',
            $item->interpreter,
            $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET)
          if $item->name =~ m{^usr/share/doc/[^/]+/examples/};

    } elsif ($item->interpreter eq '/bin/env') {

        $self->hint('script-uses-bin-env', $item->name,
            $LEFT_PARENTHESIS . $item->interpreter . $RIGHT_PARENTHESIS)
          if $item->name !~ m{^usr/share/doc/[^/]+/examples/};

        $self->hint('example-script-uses-bin-env', $item->name,
            $LEFT_PARENTHESIS . $item->interpreter . $RIGHT_PARENTHESIS)
          if $item->name =~ m{^usr/share/doc/[^/]+/examples/};

    } elsif ($item->interpreter eq 'nodejs') {

        $self->hint('script-uses-deprecated-nodejs-location',
            $item->name,
            $LEFT_PARENTHESIS . $item->interpreter . $RIGHT_PARENTHESIS)
          if $item->name !~ m{^usr/share/doc/[^/]+/examples/};

        $self->hint('example-script-uses-deprecated-nodejs-location',
            $item->name,
            $LEFT_PARENTHESIS . $item->interpreter . $RIGHT_PARENTHESIS)
          if $item->name =~ m{^usr/share/doc/[^/]+/examples/};

        # Check whether we have correct dependendies on nodejs regardless.
        $interpreter_data = $self->INTERPRETERS->value('node');

    } elsif ($basename =~ /^php/) {

        $self->hint('php-script-with-unusual-interpreter',
            $item->name,
            $LEFT_PARENTHESIS . $item->interpreter . $RIGHT_PARENTHESIS)
          if $item->name !~ m{^usr/share/doc/[^/]+/examples/};

        $self->hint('example-php-script-with-unusual-interpreter',
            $item->name,
            $LEFT_PARENTHESIS . $item->interpreter . $RIGHT_PARENTHESIS)
          if $item->name =~ m{^usr/share/doc/[^/]+/examples/};

        # This allows us to still perform the dependencies checks
        # below even when an unusual interpreter has been found.
        $interpreter_data = $self->INTERPRETERS->value('php');

    } else {
        my @private_interpreters;

        # Check if the package ships the interpreter (and it is
        # executable).
        my $name = $item->interpreter;
        if ($name =~ s{^/}{}) {
            my $file = $self->processable->installed->lookup($name);
            push(@private_interpreters, $file)
              if defined $file;

        } elsif ($item->calls_env) {
            my @files= map {
                $self->processable->installed->lookup(
                    $_ . $SLASH . $item->interpreter)
            }qw{bin usr/bin};
            push(@private_interpreters, grep { defined } @files);
        }

        $self->hint('unusual-interpreter', $item->interpreter,
            $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET)
          if (none { $_->is_file && $_->is_executable } @private_interpreters)
          && $item->name !~ m{^usr/share/doc/[^/]+/examples/};

        $self->hint('example-unusual-interpreter', $item->interpreter,
            $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET)
          if (none { $_->is_file && $_->is_executable } @private_interpreters)
          && $item->name =~ m{^usr/share/doc/[^/]+/examples/};
    }

    # Check for obsolete perl libraries
    my $perl4_prerequisites = 'libperl4-corelibs-perl | perl (<< 5.12.3-7)';

    if ($basename eq 'perl'
        && !$self->strong_prerequisites->satisfies($perl4_prerequisites)) {
        open(my $fd, '<', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        my $position = 1;
        while (my $line = <$fd>) {
            if (
                $line =~m{ (?:do|require)\s+['"] # do/require

                          # Huge list of perl4 modules...
                          (abbrev|assert|bigfloat|bigint|bigrat
                          |cacheout|complete|ctime|dotsh|exceptions
                          |fastcwd|find|finddepth|flush|getcwd|getopt
                          |getopts|hostname|importenv|look|newgetopt
                          |open2|open3|pwd|shellwords|stat|syslog
                          |tainted|termcap|timelocal|validate)
                          # ... so they end with ".pl" rather than ".pm"
                          \.pl['"]
               }xsm
            ) {

                my $module = "$1.pl";

                $self->hint(
                    'script-uses-perl4-libs-without-dep',
                    $module,
                    $LEFT_SQUARE_BRACKET
                      . $item->name
                      . $COLON
                      . $position
                      . $RIGHT_SQUARE_BRACKET,
                    "(does not satisfy $perl4_prerequisites)"
                );
            }

        } continue {
            ++$position;
        }

        close $fd;
    }

    # If we found the interpreter and the script is executable,
    # check dependencies.  This should be the last thing we do in
    # the loop so that we can use next for an early exit and
    # reduce the nesting.
    return
      unless $interpreter_data;

    return
      unless $item->is_file && $item->is_executable;

    return
      if $item->name =~ m{^usr/share/doc/} || $item->name =~ m{^usr/src/};

    if (!$versioned) {
        my $depends = $interpreter_data->{prerequisites};

        if ($depends && !$self->all_prerequisites->satisfies($depends)) {

            if ($basename =~ /^php/) {

                $self->hint(
                    'php-script-but-no-php-cli-dep',
                    $item->interpreter,
                    $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET,
                    "(does not satisfy $depends)"
                );

            } elsif ($basename =~ /^(python\d|ruby|[mg]awk)$/) {

                $self->hint((
                    "$basename-script-but-no-$basename-dep",
                    $item->interpreter,
                    $LEFT_SQUARE_BRACKET
                      . $item->name
                      . $RIGHT_SQUARE_BRACKET,
                    "(does not satisfy $depends)"
                ));

            } elsif ($basename eq 'csh'
                && $item->name =~ m{^etc/csh/login\.d/}){
                # Initialization files for csh.

            } elsif ($basename eq 'fish' && $item->name =~ m{^etc/fish\.d/}) {
                # Initialization files for fish.

            } elsif (
                $basename eq 'ocamlrun'
                && $self->all_prerequisites->matches(
                    qr/^ocaml(?:-base)?(?:-nox)?-\d\.[\d.]+/)
            ) {
                # ABI-versioned virtual packages for ocaml

            } elsif ($basename eq 'escript'
                && $self->all_prerequisites->matches(qr/^erlang-abi-[\d+\.]+$/)
            ) {
                # ABI-versioned virtual packages for erlang

            } else {

                $self->hint(
                    'missing-dep-for-interpreter',
                    $item->interpreter,
                    $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET,
                    "(does not satisfy $depends)"
                );
            }
        }

    } elsif ($self->VERSIONED_INTERPRETERS->recognizes($basename)) {
        my @versions = @{ $interpreter_data->{versions} };

        my @depends;
        for my $version (@versions) {
            my $d = $interpreter_data->{template};
            $d =~ s/\$1/$version/g;
            push(@depends, $d);
        }

        unshift(@depends, $interpreter_data->{prerequisites})
          if length $interpreter_data->{prerequisites};

        my $depends = join(' | ',  @depends);
        unless ($self->all_prerequisites->satisfies($depends)) {
            if ($basename =~ /^(wish|tclsh)/) {

                my $shell_name = $1;

                $self->hint(
                    "$shell_name-script-but-no-$shell_name-dep",
                    $item->interpreter,
                    $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET,
                    "(does not satisfy $depends)"
                );

            } else {

                $self->hint(
                    'missing-dep-for-interpreter',
                    $item->interpreter,
                    $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET,
                    "(does not satisfy $depends)"
                );
            }
        }

    } else {

        my ($version) = ($basename =~ /$interpreter_data->{regex}/);
        my $depends = $interpreter_data->{template};
        $depends =~ s/\$1/$version/g;

        unless ($self->all_prerequisites->satisfies($depends)) {
            if ($basename =~ /^(python|ruby)/) {

                $self->hint(
                    "$1-script-but-no-$1-dep",
                    $item->interpreter,
                    $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET,
                    "(does not satisfy $depends)"
                );

            } else {

                $self->hint(
                    'missing-dep-for-interpreter',
                    $item->interpreter,
                    $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET,
                    "(does not satisfy $depends)"
                );
            }
        }
    }

    return;
}

# Handle control scripts.  This is an edited version of the code for
# normal scripts above, because there were just enough differences to
# make a shared function awkward.
sub visit_control_files {
    my ($self, $item) = @_;

    return
      unless $item->is_maintainer_script;

    if ($item->is_elf) {

        $self->hint('elf-maintainer-script', "control/$item");
        return;
    }

    # keep 'env', if present
    my $interpreter = $item->hashbang;

    # keep base command without options
    $interpreter =~ s/^(\S+).*/$1/;

    if ($interpreter eq $EMPTY) {

        $self->hint('script-without-interpreter', "control/$item");
        return;
    }

    # tag for statistics
    $self->hint('maintainer-script-interpreter',
        $interpreter, "[control/$item]");

    $self->hint('interpreter-not-absolute', $interpreter, "[control/$item]")
      unless $interpreter =~ m{^/};

    my $basename = basename($interpreter);

    if ($interpreter =~ m{^/usr/local/}) {
        $self->hint('control-interpreter-in-usr-local',
            $interpreter, "[control/$item]");

    } elsif ($basename eq 'sh' || $basename eq 'bash' || $basename eq 'perl') {
        my $expected
          = ($self->INTERPRETERS->value($basename))->{folder}
          . $SLASH
          . $basename;

        my $tag_name
          = ($expected eq '/usr/bin/env perl')
          ?
          'incorrect-path-for-interpreter'
          : 'wrong-path-for-interpreter';

        $self->hint($tag_name, $interpreter, $NOT_EQUALS, $expected,
            "[control/$item]")
          unless $interpreter eq $expected;

    } elsif ($item->name eq 'config') {
        $self->hint('forbidden-config-interpreter',
            $interpreter, "[control/$item]");

    } elsif ($item->name eq 'postrm') {
        $self->hint('forbidden-postrm-interpreter',
            $interpreter, "[control/$item]");

    } elsif ($self->INTERPRETERS->recognizes($basename)) {

        my $interpreter_data = $self->INTERPRETERS->value($basename);
        my $expected = $interpreter_data->{folder} . $SLASH . $basename;

        my $tag_name
          = ($expected eq '/usr/bin/env perl')
          ?
          'incorrect-path-for-interpreter'
          : 'wrong-path-for-interpreter';

        $self->hint($tag_name, $interpreter, $NOT_EQUALS, $expected,
            "[control/$item]")
          unless $interpreter eq $expected;

        $self->hint('unusual-control-interpreter', $interpreter,
            "[control/$item]");

        # Interpreters used by preinst scripts must be in
        # Pre-Depends.  Interpreters used by postinst or prerm
        # scripts must be in Depends.
        if ($interpreter_data->{prerequisites}) {

            my $depends = Lintian::Relation->new->load(
                $interpreter_data->{prerequisites});

            if ($item->name eq 'preinst') {

                $self->hint(
                    'control-interpreter-without-predepends',
                    $interpreter,
                    "[control/$item]",
                    '(does not satisfy ' . $depends->to_string . ')'
                  )
                  unless $self->processable->relation('Pre-Depends')
                  ->satisfies($depends);

            } else {

                $self->hint(
                    'control-interpreter-without-depends',
                    $interpreter,
                    "[control/$item]",
                    '(does not satisfy ' . $depends->to_string . ')'
                  )
                  unless $self->processable->relation('strong')
                  ->satisfies($depends);
            }
        }

    } else {
        $self->hint('unknown-control-interpreter', $interpreter,
            "[control/$item]");

        # no use doing further checks if it's not a known interpreter
        return;
    }

    # perhaps we should warn about *csh even if they're somehow screwed,
    # but that's not really important...
    $self->hint('csh-considered-harmful', "control/$item",
        $LEFT_PARENTHESIS . $interpreter . $RIGHT_PARENTHESIS)
      if $basename eq 'csh' || $basename eq 'tcsh';

    return
      unless $item->is_open_ok;

    my %syntax_checkers = (sh => '/bin/dash', bash => '/bin/bash');
    my $program = $syntax_checkers{$basename};

    if (   length $program
        && -x $program
        && !script_looks_dangerous($item)) {

  # Given an interpreter and a file, run the interpreter on that file with the
  # -n option to check syntax, discarding output and returning the exit status.
        safe_qx($program, '-n', $item->unpacked_path);
        my $failed = $?;

        $self->hint('maintainer-shell-script-fails-syntax-check',
            "control/$item")
          if $failed;
    }

    # Only syntax-check scripts we can check with bash.
    my $checkbashisms = 0;
    $checkbashisms = 1
      if $item->is_shell_script
      && $basename eq 'sh';

    # now scan the file contents themselves
    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $saw_init;
    my $saw_invoke;
    my $saw_debconf;
    my $saw_bange;
    my $saw_sete;
    my $has_code;
    my $saw_statoverride_list;
    my $saw_statoverride_add;
    my $saw_udevadm_guard;
    my $saw_update_fonts;

    my $cat_string = $EMPTY;

    my $previous_line = $EMPTY;
    my $in_automatic_section = 0;

    my $position = 1;
    while (my $line = <$fd>) {

        $saw_bange = 1
          if $position == 1
          && $item->is_shell_script
          && $line =~ m{/$basename\s*.*\s-\w*e\w*\b};

        if ($line =~ m{( [#] DEBHELPER [#] )}x) {

            my $token = $1;

            $self->hint('maintainer-script-has-unexpanded-debhelper-token',
                "control/$item",
                $LEFT_PARENTHESIS . $token . $RIGHT_PARENTHESIS);
        }

        $in_automatic_section = 1
          if $line =~ /^# Automatically added by \S+\s*$/;

        $in_automatic_section = 0
          if $line eq '# End automatically added section';

        # skip empty lines
        next
          if $line =~ /^\s*$/;

        # skip comment lines
        next
          if $line =~ /^\s*\#/;

        $line = remove_comments($line);

        # Concatenate lines containing continuation character (\)
        # at the end
        if ($item->is_shell_script && $line =~ /\\$/) {

            $line =~ s/\\//;
            chomp $line;
            $previous_line .= $line;

            next;
        }

        chomp $line;

        $line = $previous_line . $line;
        $previous_line = $EMPTY;

        # Don't consider the standard dh-make boilerplate to be code.  This
        # means ignoring the framework of a case statement, the labels, the
        # echo complaining about unknown arguments, and an exit.
        $has_code = 1
          unless $has_code
          || $line =~ /^\s*set\s+-\w+\s*$/
          || $line =~ /^\s*case\s+\"?\$1\"?\s+in\s*$/
          || $line =~ /^\s*(?:[a-z|-]+|\*)\)\s*$/
          || $line =~ /^\s*[:;]+\s*$/
          || $line =~ /^\s*echo\s+\"[^\"]+\"(?:\s*>&2)?\s*$/
          || $line =~ /^\s*esac\s*$/
          || $line =~ /^\s*exit\s+\d+\s*$/;

        $saw_sete = 1
          if $item->is_shell_script
          && $line =~ /${LEADIN}set\s*(?:\s+-(?:-.*|[^e]+))*\s-\w*e/;

        if ($line =~ m{$LEADIN(?:/usr/bin/)?dpkg-statoverride\s}) {

            $saw_statoverride_add = $position
              if $line =~ /--add/;

            $saw_statoverride_list = 1
              if $line =~ /--list/;
        }

        if ($line=~ m{$LEADIN(?:/usr/bin/)?dpkg-maintscript-helper\s(\S+)}){

            my $command = $1;

            $self->seen_helper_commands->{$command} = ()
              unless $self->seen_helper_commands->{$command};

            $self->seen_helper_commands->{$command}{$item->name} = 1;
        }

        $saw_update_fonts = 1
          if $line
          =~ m{$LEADIN(?:/usr/bin/)?update-fonts-(?:alias|dir|scale)\s(\S+)};

        $saw_udevadm_guard = 1
          if $line =~ /\b(if|which|command)\s+.*udevadm/g;

        my $pointer
          = $LEFT_SQUARE_BRACKET
          . 'control'
          . $SLASH
          . $item->name
          . $COLON
          . $position
          . $RIGHT_SQUARE_BRACKET;

        if ($line =~ m{$LEADIN(?:/bin/)?udevadm\s} && $saw_sete) {

            $self->hint('udevadm-called-without-guard', $pointer)
              unless $saw_udevadm_guard
              || $line =~ m{\|\|}
              || $self->strong_prerequisites->satisfies('udev');
        }

        if ($line =~  m{ \W ( (?:/var)?/tmp | \$TMPDIR /[^)\]\}\s]+ ) }x) {

            my $indicator = $1;

            $self->hint(
                'possibly-insecure-handling-of-tmp-files-in-maintainer-script',
                $indicator,
                $pointer
              )
              if $line !~ /\bmks?temp\b/
              && $line !~ /\btempfile\b/
              && $line !~ /\bmkdir\b/
              && $line !~ /\bXXXXXX\b/
              && $line !~ /\$RANDOM/;
        }

        $self->hint('killall-is-dangerous', $pointer)
          if $line =~ /^\s*killall(?:\s|\z)/;

        $self->hint('mknod-in-maintainer-script', $pointer)
          if $line =~ /^\s*mknod(?:\s|\z)/ && $line !~ /\sp\s/;

        # Collect information about init script invocations to
        # catch running init scripts directly rather than through
        # invoke-rc.d.  Since the script is allowed to run the
        # init script directly if invoke-rc.d doesn't exist, only
        # tag direct invocations where invoke-rc.d is never used
        # in the same script.  Lots of false negatives, but
        # hopefully not many false positives.
        $saw_init = $position
          if $line =~ m{^\s*/etc/init\.d/(?:\S+)\s+[\"\']?(?:\S+)[\"\']?};

        $saw_invoke = $position
          if $line =~ m{^\s*invoke-rc\.d\s+};

        if ($item->is_shell_script) {

            $cat_string = $EMPTY
              if $cat_string ne $EMPTY
              && $line =~ /^\Q$cat_string\E$/;

            my $within_another_shell = 0;

            $within_another_shell = 1
              if $item->interpreter !~ m{(?:^|/)sh$}
              && $item->interpreter_with_options =~ /\S+\s+-c/;

            # if cat_string is set, we are in a HERE document and need not
            # check for things
            if (   $cat_string eq $EMPTY
                && $checkbashisms
                && !$within_another_shell) {

                my $found = 0;
                my $match = $EMPTY;

                # since this test is ugly, I have to do it by itself
                # detect source (.) trying to pass args to the command it runs
                # The first expression weeds out '. "foo bar"'
                if (
                      !$found
                    && $line !~  m{\A \s*\.\s+
                                   (?:\"[^\"]+\"|\'[^\']+\')\s*
                                   (?:[\&\|<;]|\d?>|\Z)}xsm
                    && $line =~ /^\s*(\.\s+[^\s;\`:]+\s+([^\s;]+))/
                ) {

                    my $extra;
                    ($match, $extra) = ($1, $2);

                    $found = 1
                      unless $extra =~ /^([\&\|<]|\d?>)/;
                }

                my $modified = $line;

                unless ($found) {

                    for my $re (@bashism_single_quote_regexes) {
                        if ($modified =~ /($re)/) {

                            $found = 1;
                            ($match) = ($line =~ /($re)/);
                            last;
                        }
                    }
                }

                # Ignore anything inside single quotes; it could be an
                # argument to grep or the like.

                # $cat_line contains the version of the line we'll check
                # for heredoc delimiters later. Initially, remove any
                # spaces between << and the delimiter to make the following
                # updates to $cat_line easier.
                my $cat_line = $modified;
                $cat_line =~ s/(<\<-?)\s+/$1/g;

                # Remove single quoted strings, with the exception
                # that we don't remove the string
                # if the quote is immediately preceded by a < or
                # a -, so we can match "foo <<-?'xyz'" as a
                # heredoc later The check is a little more greedy
                # than we'd like, but the heredoc test itself will
                # weed out any false positives
                $cat_line
                  =~ s/(^|[^<\\\"-](?:\\\\)*)\'(?:\\.|[^\\\'])+\'/$1''/g;

                unless ($found) {
                    # Remove "quoted quotes". They're likely to be
                    # inside another pair of quotes; we're not
                    # interested in them for their own sake and
                    # removing them makes finding the limits of
                    # the outer pair far easier.
                    $modified =~ s/(^|[^\\\'\"])\"\'\"/$1/g;
                    $modified =~ s/(^|[^\\\'\"])\'\"\'/$1/g;

                    $modified
                      =~ s/(^|[^\\\"](?:\\\\)*)\'(?:\\.|[^\\\'])+\'/$1''/g;

                    for my $re (@bashism_string_regexes) {
                        if ($modified =~ /($re)/) {

                            $found = 1;
                            ($match) = ($line =~ /($re)/);
                            last;
                        }
                    }
                }

                # We've checked for all the things we still want
                # to notice in double-quoted strings, so now
                # remove those strings as well.
                $cat_line
                  =~ s/(^|[^<\\\'-](?:\\\\)*)\"(?:\\.|[^\\\"])+\"/$1""/g;

                unless ($found) {
                    $modified
                      =~ s/(^|[^\\\'](?:\\\\)*)\"(?:\\.|[^\\\"])+\"/$1""/g;

                    for my $re (@bashism_regexes) {
                        if ($modified =~ /($re)/) {

                            $found = 1;
                            ($match) = ($line =~ /($re)/);
                            last;
                        }
                    }
                }

                # trim both ends
                $match =~ s/^\s+|\s+$//g;

                $self->hint('possible-bashism-in-maintainer-script',
                    "'$match'", $pointer)
                  if $found;

                # Only look for the beginning of a heredoc here,
                # after we've stripped out quoted material, to
                # avoid false positives.
                if ($cat_line
                    =~ m/(?:^|[^<])\<\<\-?\s*(?:[\\]?(\w+)|[\'\"](.*?)[\'\"])/)
                {
                    $cat_string = $1 // $2;
                }
            }

            if (!$cat_string) {

                $self->generic_check_bad_command($item->name, $line,
                    $position, 0,$in_automatic_section);

                $saw_debconf = 1
                  if $line =~ m{/usr/share/debconf/confmodule};

                $self->hint('read-in-maintainer-script', $pointer)
                  if $line =~ /^\s*read(?:\s|\z)/ && !$saw_debconf;

                $self->hint('multi-arch-same-package-calls-pycompile',$pointer)
                  if $line =~ /^\s*py3?compile(?:\s|\z)/
                  &&$self->processable->fields->value('Multi-Arch') eq 'same';

                $self->hint('maintainer-script-modifies-inetd-conf',$pointer)
                  if $line =~ m{>\s*/etc/inetd\.conf(?:\s|\Z)}
                  && !$self->processable->relation('Provides')
                  ->satisfies('inet-superserver');

                $self->hint('maintainer-script-modifies-inetd-conf',$pointer)
                  if $line=~ m{^\s*(?:cp|mv)\s+(?:.*\s)?/etc/inetd\.conf\s*$}
                  && !$self->processable->relation('Provides')
                  ->satisfies('inet-superserver');

                # Check for running commands with a leading path.
                #
                # Unfortunately, our $LEADIN string doesn't work
                # well for this in the presence of commands that
                # contain backquoted expressions because it can't
                # tell the difference between the initial backtick
                # and the closing backtick.  We therefore first
                # extract all backquoted expressions and check
                # them separately, and then remove them from a
                # copy of a string and then check it for bashisms.
                while ($line =~ /\`([^\`]+)\`/g) {

                    my $mangled = $1;

                    if (
                        $mangled =~ m{ $LEADIN
                                      (/(?:usr/)?s?bin/[\w.+-]+)
                                      (?:\s|;|\Z)}xsm
                    ) {
                        my $command = $1;

                        $self->hint('command-with-path-in-maintainer-script',
                            $command, $pointer, '(in backticks)')
                          unless $in_automatic_section;
                    }
                }

                # check for test syntax
                if(
                    $line =~ m{\[\s+
                          (?:!\s+)? -x \s+
                          (/(?:usr/)?s?bin/[\w.+-]+)
                          \s+ \]}xsm
                ){
                    my $command = $1;

                    $self->hint('command-with-path-in-maintainer-script',
                        $command, $pointer, '(in test syntax)')
                      unless $in_automatic_section;
                }

                my $mangled = $line;
                $mangled =~ s/\`[^\`]+\`//g;

                if ($mangled =~ m{$LEADIN(/(?:usr/)?s?bin/[\w.+-]+)(?:\s|;|$)})
                {
                    my $command = $1;

                    $self->hint('command-with-path-in-maintainer-script',
                        $command, $pointer, '(plain script)')
                      unless $in_automatic_section;
                }
            }
        }

        for my $pattern (keys %prerequisite_by_command_pattern) {

            next
              unless $line =~ /($pattern)/;

            my $command = $1;

            next
              if $line =~ /-x\s+\S*$pattern/
              || $line =~ /(?:which|type)\s+$pattern/
              || $line =~ /command\s+.*?$pattern/
              || $line =~ m{ [|][|] \s* true \b }x;

            my $requirement = $prerequisite_by_command_pattern{$pattern};

            my $first_alternative = $requirement;
            $first_alternative =~ s/[ \(].*//;

            $self->hint(
                "maintainer-script-needs-depends-on-$first_alternative",
                $command, $pointer, "(does not satisfy $requirement)")
              unless $self->processable->relation('strong')
              ->satisfies($requirement)
              || $self->processable->name eq $first_alternative
              || $item->name eq 'postrm';
        }

        $self->generic_check_bad_command($item->name, $line, $position, 1,
            $in_automatic_section);

        for my $old_version (sort keys %{$self->old_versions}) {

            next
              if $old_version =~ /^\d+$/;

            if ($line
                =~m{$LEADIN(?:/usr/bin/)?dpkg\s+--compare-versions\s+.*\b\Q$old_version\E(?!\.)\b}
            ) {
                my $date
                  = strftime('%Y-%m-%d',
                    gmtime $self->old_versions->{$old_version});
                my $epoch
                  = strftime('%Y-%m-%d', gmtime $OLDSTABLE_RELEASE_EPOCH);

                $self->hint(
                    'maintainer-script-supports-ancient-package-version',
                    $old_version, "($date < $epoch)", $pointer);

                last;
            }
        }

        if ($line =~ m{$LEADIN(?:/usr/sbin/)?update-inetd\s}) {

            $self->hint('maintainer-script-has-invalid-update-inetd-options',
                '(--pattern with --add)', $pointer)
              if $line =~ /--pattern/
              && $line =~ /--add/;

            $self->hint('maintainer-script-has-invalid-update-inetd-options',
                '(--group without --add)', $pointer)
              if $line =~ /--group/
              && $line !~ /--add/;
        }

        my $pre_depends = $self->processable->relation('Pre-Depends');

        my $systemd_native_prerequisites = 'init-system-helpers (>= 1.54~)';

        $self->hint('skip-systemd-native-flag-missing-pre-depends',
            $pointer, "(does not satisfy $systemd_native_prerequisites)")
          if $line =~ /invoke-rc.d\b.*--skip-systemd-native\b/
          && !$pre_depends->satisfies($systemd_native_prerequisites);

        if (   $line =~ m{$LEADIN(?:/usr/sbin/)?dpkg-divert\s}
            && $line !~ /--(?:help|list|truename|version)/) {

            $self->hint('package-uses-local-diversion', $pointer)
              if $line =~ /--local/;

            my $mode = $line =~ /--remove/ ? 'remove' : 'add';

            my ($divert) = ($line =~ /dpkg-divert\s*(.*)$/);

            $divert =~ s{\s*(?:\$[{]?[\w:=-]+[}]?)*\s*
                                # options without arguments
                              --(?:add|quiet|remove|rename|no-rename|test|local
                                # options with arguments
                                |(?:admindir|divert|package) \s+ \S+)
                              \s*}{}gxsm;

            # Remove unpaired opening or closing parenthesis
            1 while ($divert =~ m/\G.*?\(.+?\)/gc);
            $divert =~ s/\G(.*?)[()]/$1/;
            pos($divert) = undef;

            # Remove unpaired opening or closing braces
            1 while ($divert =~ m/\G.*?{.+?}/gc);
            $divert =~ s/\G(.*?)[{}]/$1/;
            pos($divert) = undef;

            # position after the last pair of quotation marks, if any
            1 while ($divert =~ m/\G.*?(["']).+?\1/gc);

            # Strip anything matching and after '&&', '||', ';', or '>'
            # this is safe only after we are positioned after the last pair
            # of quotation marks
            $divert =~ s/\G.+?\K(?: && | \|\| | ; | \d*> ).*$//x;
            pos($divert) = undef;

            # Remove quotation marks, they affect:
            # * our var to regex trick
            # * stripping the initial slash if the path was quoted
            $divert =~ s/[\"\']//g;

            # remove the leading / because it's not in the index hash
            $divert =~ s{^/}{};

            # trim both ends
            $divert =~ s/^\s+|\s+$//g;

            $divert = quotemeta($divert);

            # For now just replace variables, they will later be normalised
            $self->expand_diversions(1)
              if $divert =~ s/\\\$\w+/.+/g;

            $self->expand_diversions(1)
              if $divert =~ s/\\\$\\[{]\w+.*?\\[}]/.+/g;

            # handle $() the same way:
            $self->expand_diversions(1)
              if $divert =~ s/\\\$\\\(.+?\\\)/.+/g;

            my %diversion;
            $diversion{script} = $item;
            $diversion{position} = $position;

            $self->added_diversions->{$divert} = \%diversion
              if $mode eq 'add';

            push(@{$self->removed_diversions->{$divert}}, \%diversion)
              if $mode eq 'remove';

            die encode_utf8("mode has unknown value: $mode")
              if none { $mode eq $_ } qw{add remove};
        }

    } continue {
        ++$position;
    }

    close($fd);

    if ($item->name eq 'postinst' && !$saw_update_fonts) {

        $self->hint('missing-call-to-update-fonts', $_, '[control/postinst]')
          for @{$self->x_fonts};
    }

    $self->hint('maintainer-script-calls-init-script-directly',
        "[control/$item:$saw_init]")
      if $saw_init && !$saw_invoke;

    $self->hint('maintainer-script-empty', "control/$item")
      unless $has_code;

    $self->hint('maintainer-script-without-set-e', "control/$item")
      if $item->is_shell_script && !$saw_sete && $saw_bange;

    $self->hint('maintainer-script-ignores-errors', "control/$item")
      if $item->is_shell_script && !$saw_sete && !$saw_bange;

    $self->hint(
        'unconditional-use-of-dpkg-statoverride',
        "[control/$item:$saw_statoverride_add]"
    )if $saw_statoverride_add && !$saw_statoverride_list;

    return;
}

sub installable {
    my ($self) = @_;

    for my $command (qw(rm_conffile mv_conffile symlink_to_dir)) {

        next
          unless $self->seen_helper_commands->{$command};

        # dpkg-maintscript-helper(1) recommends the snippets are in all
        # maintainer scripts but they are not strictly required in prerm.
        for my $maintainer_script (qw(preinst postinst postrm)) {

            $self->hint('missing-call-to-dpkg-maintscript-helper',
                $command, "[control/$maintainer_script]")
              unless $self->seen_helper_commands->{$command}
              {$maintainer_script};
        }
    }

    # If any of the maintainer scripts used a variable in the file or
    # diversion name normalise them all
    if ($self->expand_diversions) {

        for my $divert (keys %{$self->removed_diversions},
            keys %{$self->added_diversions}) {

            # if a wider regex was found, the entries might no longer be there
            next
              unless exists $self->removed_diversions->{$divert}
              || exists $self->added_diversions->{$divert};

            my $widerrx = $divert;
            my $wider = $widerrx;
            $wider =~ s/\\//g;

            # find the widest regex:
            my @matches = grep {
                my $lrx = $_;
                my $l = $lrx;
                $l =~ s/\\//g;

                if ($wider =~ m/^$lrx$/) {
                    $widerrx = $lrx;
                    $wider = $l;
                    1;
                } elsif ($l =~ m/^$widerrx$/) {
                    1;
                } else {
                    0;
                }
            } (
                keys %{$self->removed_diversions},
                keys %{$self->added_diversions});

            # replace all the occurrences with the widest regex:
            for my $k (@matches) {

                next
                  if $k eq $widerrx;

                if (exists $self->removed_diversions->{$k}) {

                    $self->removed_diversions->{$widerrx}
                      = $self->removed_diversions->{$k};

                    delete $self->removed_diversions->{$k};
                }

                if (exists $self->added_diversions->{$k}) {

                    $self->added_diversions->{$widerrx}
                      = $self->added_diversions->{$k};

                    delete $self->added_diversions->{$k};
                }
            }
        }
    }

    for my $divert (keys %{$self->removed_diversions}) {

        if (exists $self->added_diversions->{$divert}) {
            # just mark the entry, because a --remove might
            # happen in two branches in the script, i.e. we
            # see it twice, which is not a bug
            $self->added_diversions->{$divert}{removed} = 1;

        } else {

            for my $item (@{$self->removed_diversions->{$divert}}) {

                my $script = $item->{script};
                my $position = $item->{position};

                next
                  unless $script eq 'postrm';

                # Allow preinst and postinst to remove diversions the
                # package doesn't add to clean up after previous
                # versions of the package.

                my $unquoted = unquote($divert, $self->expand_diversions);
                my $pointer = "[$script:$position]";

                $self->hint('remove-of-unknown-diversion', $unquoted,$pointer);
            }
        }
    }

    for my $divert (keys %{$self->added_diversions}) {

        my $script = $self->added_diversions->{$divert}{script};
        my $position = $self->added_diversions->{$divert}{position};

        my $pointer = "[$script:$position]";

        my $divertrx = $divert;
        my $unquoted = unquote($divert, $self->expand_diversions);

        $self->hint('orphaned-diversion', $unquoted, $pointer)
          unless exists $self->added_diversions->{$divertrx}{removed};

        # Handle man page diversions somewhat specially.  We may
        # divert away a man page in one section without replacing that
        # same file, since we're installing a man page in a different
        # section.  An example is diverting a man page in section 1
        # and replacing it with one in section 1p (such as
        # libmodule-corelist-perl at the time of this writing).
        #
        # Deal with this by turning all man page diversions into
        # wildcard expressions instead that match everything in the
        # same numeric section so that they'll match the files shipped
        # in the package.
        if ($divertrx =~ m{^(usr\\/share\\/man\\/\S+\\/.*\\\.\d)\w*(\\\.gz\z)})
        {
            $divertrx = "$1.*$2";
            $self->expand_diversions(1);
        }

        if ($self->expand_diversions) {
            $self->hint('diversion-for-unknown-file', $unquoted, $pointer)
              unless (
                any { /$divertrx/ }
                @{$self->processable->installed->sorted_list});

        } else {
            $self->hint('diversion-for-unknown-file', $unquoted, $pointer)
              unless $self->processable->installed->lookup($unquoted);
        }
    }

    return;
}

# -----------------------------------

# try generic bad maintainer script command tagging
sub generic_check_bad_command {
    my ($self, $script, $line, $position, $find_in_cat_string,
        $in_automatic_section)
      = @_;

    for my $tag_name ($self->BAD_MAINTAINER_COMMANDS->all) {

        my $command_data= $self->BAD_MAINTAINER_COMMANDS->value($tag_name);

        next
          if $in_automatic_section
          && $command_data->{ignore_automatic_sections};

        next
          unless $script =~ $command_data->{script_include_regex};

        next
          unless $find_in_cat_string == $command_data->{in_cat_string};

        if ($line =~ m{ ( $command_data->{command_pattern} ) }x) {

            my $bad_command = $1 // $EMPTY;

            # trim both ends
            $bad_command =~ s/^\s+|\s+$//g;

            $self->hint($tag_name,$DOUBLE_QUOTE . $bad_command . $DOUBLE_QUOTE,
                "[control/$script:$position]")
              unless $self->processable->name
              =~ $command_data->{package_exclude_regex};
        }
    }

    return;
}

# Returns non-zero if the given file is not actually a shell script,
# just looks like one.
sub script_looks_dangerous {
    my ($item) = @_;

    my $result = 0;
    my $shell_variable_name = '0';
    my $backgrounded = 0;

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $position = 1;
    while (my $line = <$fd>) {

        chomp $line;

        next
          if $line =~ /^#/;

        next
          unless length $line;

        last
          if $position >= $MAXIMUM_LINES_ANALYZED;

        if (
            $line =~ m<
            # the exec should either be "eval"ed or a new statement
            (?:^\s*|\beval\s*[\'\"]|(?:;|&&|\b(?:then|else))\s*)

            # eat anything between the exec and $0
            exec\s*.+\s*

            # optionally quoted executable name (via $0)
            .?\$$shell_variable_name.?\s*

            # optional "end of options" indicator
            (?:--\s*)?

            # Match expressions of the form '${1+$@}', '${1:+"$@"',
            # '"${1+$@', "$@", etc where the quotes (before the dollar
            # sign(s)) are optional and the second (or only if the $1
            # clause is omitted) parameter may be $@ or $*.
            #
            # Finally the whole subexpression may be omitted for scripts
            # which do not pass on their parameters (i.e. after re-execing
            # they take their parameters (and potentially data) from stdin
            .?(?:\$[{]1:?\+.?)?(?:\$[\@\*])?>x
        ) {
            $result = 1;

            last;

        } elsif ($line =~ /^\s*(\w+)=\$0;/) {
            $shell_variable_name = $1;

        } elsif (
            $line =~ m<
            # Match scripts which use "foo $0 $@ &\nexec true\n"
            # Program name
            \S+\s+

            # As above
            .?\$$shell_variable_name.?\s*
            (?:--\s*)?
            .?(?:\$[{]1:?\+.?)?(?:\$[\@\*])?.?\s*\&>x
        ) {

            $backgrounded = 1;

        } elsif (
            $backgrounded
            && $line =~ m{
            # the exec should either be "eval"ed or a new statement
            (?:^\s*|\beval\s*[\'\"]|(?:;|&&|\b(?:then|else))\s*)
            exec\s+true(?:\s|\Z)}x
        ) {

            $result = 1;
            last;
        }

    } continue {
        ++$position;
    }

    close $fd;

    return $result;
}

sub remove_comments {
    my ($line) = @_;

    return $line
      unless length $line;

    my $simplified = $line;

    # Remove quoted strings so we can more easily ignore comments
    # inside them
    $simplified =~ s/(^|[^\\](?:\\\\)*)\'(?:\\.|[^\\\'])+\'/$1''/g;
    $simplified =~ s/(^|[^\\](?:\\\\)*)\"(?:\\.|[^\\\"])+\"/$1""/g;

    # If the remaining string contains what looks like a comment,
    # eat it. In either case, swap the unmodified script line
    # back in for processing (if required) and return it.
    if ($simplified =~ m/(?:^|[^[\\])[\s\&;\(\)](\#.*$)/) {

        my $comment = $1;

        # eat comment
        $line =~ s/\Q$comment\E//;
    }

    return $line;
}

sub unquote {
    my ($string, $replace_regex) = @_;

    $string =~ s{\\}{}g;

    $string =~ s{\.\+}{*}g
      if $replace_regex;

    return $string;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
