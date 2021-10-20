# script/syntax -- lintian check script -*- perl -*-
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

package Lintian::Check::Script::Syntax;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;

use Lintian::IPC::Run3 qw(safe_qx);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $MAXIMUM_LINES_ANALYZED => 54;

# exclude some shells. zsh -n is broken, see #485885
const my %SYNTAX_CHECKERS => (
    sh => [qw{/bin/dash -n}],
    bash => [qw{/bin/bash -n}]);

sub visit_installed_files {
    my ($self, $item) = @_;

    # Consider /usr/src/ scripts as "documentation"
    # - packages containing /usr/src/ tend to be "-source" .debs
    #   and usually come with overrides
    # no checks necessary at all for scripts in /usr/share/doc/
    # unless they are examples
    return
      if ($item->name =~ m{^usr/share/doc/} || $item->name =~ m{^usr/src/})
      && $item->name !~ m{^usr/share/doc/[^/]+/examples/};

    # Syntax-check most shell scripts, but don't syntax-check
    # scripts that end in .dpatch.  bash -n doesn't stop checking
    # at exit 0 and goes on to blow up on the patch itself.
    $self->hint('shell-script-fails-syntax-check',$item->name)
      if $self->fails_syntax_check($item)
      && $item->name !~ m{^usr/share/doc/[^/]+/examples/}
      && $item->name !~ /\.dpatch$/
      && $item->name !~ /\.erb$/;

    $self->hint('example-shell-script-fails-syntax-check',$item->name)
      if $self->fails_syntax_check($item)
      && $item->name =~ m{^usr/share/doc/[^/]+/examples/}
      && $item->name !~ /\.dpatch$/
      && $item->name !~ /\.erb$/;

    return;
}

sub visit_control_files {
    my ($self, $item) = @_;

    $self->hint('maintainer-shell-script-fails-syntax-check',"control/$item")
      if $self->fails_syntax_check($item);

    return;
}

sub fails_syntax_check {
    my ($self, $item) = @_;

    return 0
      unless length $item->interpreter;

    my $basename = basename($item->interpreter);

    my @command;

    # "Perl doesn't distinguish between restricted hashes and readonly hashes."
    # https://metacpan.org/pod/Const::Fast#CAVEATS
    @command = @{$SYNTAX_CHECKERS{$basename}}
      if exists $SYNTAX_CHECKERS{$basename};

    return 0
      unless @command;

    my $program = $command[0];
    return 0
      unless length $program
      && -x $program;

    return 0
      unless $item->is_open_ok;

    return 0
      if script_looks_dangerous($item);

  # Given an interpreter and a file, run the interpreter on that file with the
  # -n option to check syntax, discarding output and returning the exit status.
    safe_qx(@command, $item->unpacked_path);
    my $failed = $?;

    return $failed;
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

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
