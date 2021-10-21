# scripts -- lintian check script -*- perl -*-
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
const my $LEADING_PATTERN=>
'(?:(?:^|[`&;(|{])\s*|(?:if|then|do|while|!)\s+|env(?:\s+[[:alnum:]_]+=(?:\S+|\"[^"]*\"|\'[^\']*\'))*\s+)';
const my $LEADING_REGEX => qr/$LEADING_PATTERN/;

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

                $command_pattern=~ s/\$[{]LEADING_PATTERN[}]/$LEADING_PATTERN/;

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

sub visit_installed_files {
    my ($self, $item) = @_;

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
        && (!$item->is_file || !$item->is_executable)
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

    return
      unless $item->is_open_ok;

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

    return
      unless $item->is_open_ok;

    # now scan the file contents themselves
    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $saw_debconf;
    my $saw_bange;
    my $saw_sete;
    my $saw_udevadm_guard;

    my $cat_string = $EMPTY;

    my $previous_line = $EMPTY;
    my $in_automatic_section = 0;

    my $position = 1;
    while (my $line = <$fd>) {

        $saw_bange = 1
          if $position == 1
          && $item->is_shell_script
          && $line =~ m{/$basename\s*.*\s-\w*e\w*\b};

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

        $saw_sete = 1
          if $item->is_shell_script
          && $line =~ /${LEADING_REGEX}set\s*(?:\s+-(?:-.*|[^e]+))*\s-\w*e/;

        $saw_udevadm_guard = 1
          if $line =~ /\b(if|which|command)\s+.*udevadm/g;

        if ($line =~ m{$LEADING_REGEX(?:/bin/)?udevadm\s} && $saw_sete) {

            $self->hint('udevadm-called-without-guard',
                "[control/$item:$position]")
              unless $saw_udevadm_guard
              || $line =~ m{\|\|}
              || $self->strong_prerequisites->satisfies('udev');
        }

        if ($item->is_shell_script) {

            $cat_string = $EMPTY
              if $cat_string ne $EMPTY
              && $line =~ /^\Q$cat_string\E$/;

            my $within_another_shell = 0;

            $within_another_shell = 1
              if $item->interpreter !~ m{(?:^|/)sh$}
              && $item->interpreter_with_options =~ /\S+\s+-c/;

            if (!$cat_string) {

                $self->generic_check_bad_command($item->name, $line,
                    $position, 0,$in_automatic_section);

                $saw_debconf = 1
                  if $line =~ m{/usr/share/debconf/confmodule};

                $self->hint('read-in-maintainer-script',
                    "[control/$item:$position]")
                  if $line =~ /^\s*read(?:\s|\z)/ && !$saw_debconf;

                $self->hint('multi-arch-same-package-calls-pycompile',
                    "[control/$item:$position]")
                  if $line =~ /^\s*py3?compile(?:\s|\z)/
                  &&$self->processable->fields->value('Multi-Arch') eq 'same';

                $self->hint('maintainer-script-modifies-inetd-conf',
                    "[control/$item:$position]")
                  if $line =~ m{>\s*/etc/inetd\.conf(?:\s|\Z)}
                  && !$self->processable->relation('Provides')
                  ->satisfies('inet-superserver');

                $self->hint('maintainer-script-modifies-inetd-conf',
                    "[control/$item:$position]")
                  if $line=~ m{^\s*(?:cp|mv)\s+(?:.*\s)?/etc/inetd\.conf\s*$}
                  && !$self->processable->relation('Provides')
                  ->satisfies('inet-superserver');

                # Check for running commands with a leading path.
                #
                # Unfortunately, our $LEADING_REGEX string doesn't work
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
                        $mangled =~ m{ $LEADING_REGEX
                                      (/(?:usr/)?s?bin/[\w.+-]+)
                                      (?:\s|;|\Z)}xsm
                    ) {
                        my $command = $1;

                        $self->hint(
                            'command-with-path-in-maintainer-script',
                            $command,
                            "[control/$item:$position]",
                            '(in backticks)'
                        )unless $in_automatic_section;
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
                        $command, "[control/$item:$position]",
                        '(in test syntax)')
                      unless $in_automatic_section;
                }

                my $mangled = $line;
                $mangled =~ s/\`[^\`]+\`//g;

                if ($mangled
                    =~ m{$LEADING_REGEX(/(?:usr/)?s?bin/[\w.+-]+)(?:\s|;|$)}){
                    my $command = $1;

                    $self->hint('command-with-path-in-maintainer-script',
                        $command, "[control/$item:$position]",'(plain script)')
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
                $command,
                "[control/$item:$position]",
                "(does not satisfy $requirement)"
              )
              unless $self->processable->relation('strong')
              ->satisfies($requirement)
              || $self->processable->name eq $first_alternative
              || $item->name eq 'postrm';
        }

        $self->generic_check_bad_command($item->name, $line, $position, 1,
            $in_automatic_section);

        if ($line =~ m{$LEADING_REGEX(?:/usr/sbin/)?update-inetd\s}) {

            $self->hint(
                'maintainer-script-has-invalid-update-inetd-options',
                '(--pattern with --add)',
                "[control/$item:$position]"
              )
              if $line =~ /--pattern/
              && $line =~ /--add/;

            $self->hint(
                'maintainer-script-has-invalid-update-inetd-options',
                '(--group without --add)',
                "[control/$item:$position]"
              )
              if $line =~ /--group/
              && $line !~ /--add/;
        }

    } continue {
        ++$position;
    }

    close $fd;

    $self->hint('maintainer-script-without-set-e', "control/$item")
      if $item->is_shell_script && !$saw_sete && $saw_bange;

    $self->hint('maintainer-script-ignores-errors', "control/$item")
      if $item->is_shell_script && !$saw_sete && !$saw_bange;

    return;
}

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

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
