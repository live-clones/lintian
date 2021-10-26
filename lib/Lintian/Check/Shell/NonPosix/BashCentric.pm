# shell/non-posix/bash-centric -- lintian check script -*- perl -*-
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

# bashism sounded too much like fascism
package Lintian::Check::Shell::NonPosix::BashCentric;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;
use List::SomeUtils qw(uniq);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SLASH => q{/};
const my $COLON => q{:};
const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

# When detecting commands inside shell scripts, use this regex to match the
# beginning of the command rather than checking whether the command is at the
# beginning of a line.
const my $LEADING_PATTERN=>
'(?:(?:^|[`&;(|{])\s*|(?:if|then|do|while|!)\s+|env(?:\s+[[:alnum:]_]+=(?:\S+|\"[^"]*\"|\'[^\']*\'))*\s+)';
const my $LEADING_REGEX => qr/$LEADING_PATTERN/;

my @bashism_single_quote_regexes = (
    $LEADING_REGEX
      . qr{echo\s+(?:-[^e\s]+\s+)?\'[^\']*(\\[abcEfnrtv0])+.*?[\']},
    # unsafe echo with backslashes
    $LEADING_REGEX . qr{source\s+[\"\']?(?:\.\/|[\/\$\w~.-])\S*},
    # should be '.', not 'source'
);

my @bashism_string_regexes = (
    qr/\$\[\w+\]/,                 # arith not allowed
    qr/\$\{\w+\:\d+(?::\d+)?\}/,   # ${foo:3[:1]}
    qr/\$\{\w+(\/.+?){1,2}\}/,     # ${parm/?/pat[/str]}
    qr/\$\{\#?\w+\[[0-9\*\@]+\]\}/,# bash arrays, ${name[0|*|@]}
    qr/\$\{!\w+[\@*]\}/,           # ${!prefix[*|@]}
    qr/\$\{!\w+\}/,                # ${!name}
    qr/(\$\(|\`)\s*\<\s*\S+\s*([\)\`])/, # $(\< foo) should be $(cat foo)
    qr/\$\{?RANDOM\}?\b/,          # $RANDOM
    qr/\$\{?(OS|MACH)TYPE\}?\b/,   # $(OS|MACH)TYPE
    qr/\$\{?HOST(TYPE|NAME)\}?\b/, # $HOST(TYPE|NAME)
    qr/\$\{?DIRSTACK\}?\b/,        # $DIRSTACK
    qr/\$\{?EUID\}?\b/,            # $EUID should be "id -u"
    qr/\$\{?UID\}?\b/,             # $UID should be "id -ru"
    qr/\$\{?SECONDS\}?\b/,         # $SECONDS
    qr/\$\{?BASH_[A-Z]+\}?\b/,     # $BASH_SOMETHING
    qr/\$\{?SHELLOPTS\}?\b/,       # $SHELLOPTS
    qr/\$\{?PIPESTATUS\}?\b/,      # $PIPESTATUS
    qr/\$\{?SHLVL\}?\b/,           # $SHLVL
    qr/<<</,                       # <<< here string
    $LEADING_REGEX
      . qr/echo\s+(?:-[^e\s]+\s+)?\"[^\"]*(\\[abcEfnrtv0])+.*?[\"]/,
    # unsafe echo with backslashes
);

my @bashism_regexes = (
    qr/(?:^|\s+)function \w+(\s|\(|\Z)/,  # function is useless
    qr/(test|-o|-a)\s*[^\s]+\s+==\s/, # should be 'b = a'
    qr/\[\s+[^\]]+\s+==\s/,        # should be 'b = a'
    qr/\s(\|\&)/,                  # pipelining is not POSIX
    qr/[^\\\$]\{(?:[^\s\\\}]*?,)+[^\\\}\s]*\}/, # brace expansion
    qr/(?:^|\s+)\w+\[\d+\]=/,      # bash arrays, H[0]
    $LEADING_REGEX . qr/read\s+(?:-[a-qs-zA-Z\d-]+)/,
    # read with option other than -r
    $LEADING_REGEX . qr/read\s*(?:-\w+\s*)*(?:\".*?\"|[\'].*?[\'])?\s*(?:;|$)/,
    # read without variable
    qr/\&>/,                       # cshism
    qr/(<\&|>\&)\s*((-|\d+)[^\s;|)`&\\\\]|[^-\d\s]+)/, # should be >word 2>&1
    qr/\[\[(?!:)/,                 # alternative test command
    $LEADING_REGEX . qr/select\s+\w+/,    # 'select' is not POSIX
    $LEADING_REGEX . qr/echo\s+(-n\s+)?-n?en?/,  # echo -e
    $LEADING_REGEX . qr/exec\s+-[acl]/,   # exec -c/-l/-a name
    qr/(?:^|\s+)let\s/,            # let ...
    qr/(?<![\$\(])\(\(.*\)\)/,     # '((' should be '$(('
    qr/\$\[[^][]+\]/,              # '$[' should be '$(('
    qr/(\[|test)\s+-a/,            # test with unary -a (should be -e)
    qr{/dev/(tcp|udp)},            # /dev/(tcp|udp)
    $LEADING_REGEX . qr/\w+\+=/,   # should be "VAR="${VAR}foo"
    $LEADING_REGEX . qr/suspend\s/,
    $LEADING_REGEX . qr/caller\s/,
    $LEADING_REGEX . qr/complete\s/,
    $LEADING_REGEX . qr/compgen\s/,
    $LEADING_REGEX . qr/declare\s/,
    $LEADING_REGEX . qr/typeset\s/,
    $LEADING_REGEX . qr/disown\s/,
    $LEADING_REGEX . qr/builtin\s/,
    $LEADING_REGEX . qr/set\s+-[BHT]+/,   # set -[BHT]
    $LEADING_REGEX . qr/alias\s+-p/,      # alias -p
    $LEADING_REGEX . qr/unalias\s+-a/,    # unalias -a
    $LEADING_REGEX . qr/local\s+-[a-zA-Z]+/, # local -opt
    qr/(?:^|\s+)\s*\(?\w*[^\(\w\s]+\S*?\s*\(\)\s*([\{|\(]|\Z)/,
    # function names should only contain [a-z0-9_]
    $LEADING_REGEX . qr/(push|pop)d(\s|\Z)/,   # (push|pod)d
    $LEADING_REGEX . qr/export\s+-[^p]/,  # export only takes -p as an option
    $LEADING_REGEX . qr/ulimit(\s|\Z)/,
    $LEADING_REGEX . qr/shopt(\s|\Z)/,
    $LEADING_REGEX . qr/type\s/,
    $LEADING_REGEX . qr/time\s/,
    $LEADING_REGEX . qr/dirs(\s|\Z)/,
    qr/(?:^|\s+)[<>]\(.*?\)/,       # <() process substitution
    qr/(?:^|\s+)readonly\s+-[af]/,  # readonly -[af]
    $LEADING_REGEX . qr/(sh|\$\{?SHELL\}?) -[rD]/, # sh -[rD]
    $LEADING_REGEX . qr/(sh|\$\{?SHELL\}?) --\w+/, # sh --long-option
    $LEADING_REGEX . qr/(sh|\$\{?SHELL\}?) [-+]O/, # sh [-+]O
);

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless length $item->interpreter;

    my $basename = basename($item->interpreter);

    return
      unless $basename eq 'sh';

    $self->check_bash_centric($item, 'bash-term-in-posix-shell', $item->name);

    return;
}

sub visit_control_files {
    my ($self, $item) = @_;

    return
      unless length $item->interpreter;

    my $basename = basename($item->interpreter);

    return
      unless $basename eq 'sh';

    $self->check_bash_centric($item, 'possible-bashism-in-maintainer-script',
        "control/$item");

    return;
}

sub check_bash_centric {
    my ($self, $item, $tag_name, $label) = @_;

    return
      unless $item->is_open_ok;

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $stashed = $EMPTY;

    my $position = 1;
    while (my $possible_continuation = <$fd>) {

        chomp $possible_continuation;

        # skip empty lines
        next
          if $possible_continuation =~ /^\s*$/;

        # skip comment lines
        next
          if $possible_continuation =~ /^\s*\#/;

        my $no_comment = remove_comments($possible_continuation);

        # Concatenate lines containing continuation character (\)
        # at the end
        if ($no_comment =~ s{\\$}{}) {

            $stashed .= $no_comment;

            next;
        }

        my $line = $stashed . $no_comment;
        $stashed = $EMPTY;

        my $pointer
          = $LEFT_SQUARE_BRACKET
          . $label
          . $COLON
          . $position
          . $RIGHT_SQUARE_BRACKET;

        my @matches = uniq +$self->check_line($line);

        for my $match (@matches) {

            my $printable = "'$match'";
            $printable = '{hex:' . sprintf('%vX', $match) . '}'
              if $match =~ /\P{XPosixPrint}/;

            $self->hint($tag_name, $pointer, $printable);
        }

    } continue {
        ++$position;
    }

    close $fd;

    return;
}

sub check_line {
    my ($self, $line) = @_;

    my @matches;

    # since this test is ugly, I have to do it by itself
    # detect source (.) trying to pass args to the command it runs
    # The first expression weeds out '. "foo bar"'
    if (
        $line !~  m{\A \s*\.\s+
                                   (?:\"[^\"]+\"|\'[^\']+\')\s*
                                   (?:[\&\|<;]|\d?>|\Z)}xsm
        && $line =~ /^\s*(\.\s+[^\s;\`:]+\s+([^\s;]+))/
    ) {

        my ($dot_command, $extra) = ($1, $2);

        push(@matches, $dot_command)
          if length $dot_command
          && $extra !~ m{^ & | [|] | < | \d? > }x;
    }

    my $modified = $line;

    for my $regex (@bashism_single_quote_regexes) {
        if ($modified =~ $regex) {

            # on unmodified line
            my ($match) = ($line =~ /($regex)/);

            push(@matches, $match)
              if length $match;
        }
    }

    # Ignore anything inside single quotes; it could be an
    # argument to grep or the like.

    # Remove "quoted quotes". They're likely to be
    # inside another pair of quotes; we're not
    # interested in them for their own sake and
    # removing them makes finding the limits of
    # the outer pair far easier.
    $modified =~ s/(^|[^\\\'\"])\"\'\"/$1/g;
    $modified =~ s/(^|[^\\\'\"])\'\"\'/$1/g;

    $modified =~ s/(^|[^\\\"](?:\\\\)*)\'(?:\\.|[^\\\'])+\'/$1''/g;

    for my $regex (@bashism_string_regexes) {
        if ($modified =~ $regex) {

            # on unmodified line
            my ($match) = ($line =~ /($regex)/);

            $match //= $EMPTY;

            push(@matches, $match)
              if length $match;
        }
    }

    $modified =~ s/(^|[^\\\'](?:\\\\)*)\"(?:\\.|[^\\\"])+\"/$1""/g;

    for my $regex (@bashism_regexes) {
        if ($modified =~ $regex) {

            # on unmodified line
            my ($match) = ($line =~ /($regex)/);

            $match //= $EMPTY;

            push(@matches, $match)
              if length $match;
        }
    }

    # trim both ends of each element
    s/^\s+|\s+$//g for @matches;

    my @meaningful = grep { length } @matches;

    return @meaningful;
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
