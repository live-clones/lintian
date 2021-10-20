# maintainer-scripts/helper/dpkg -- lintian check script -*- perl -*-
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

package Lintian::Check::MaintainerScripts::Helper::Dpkg;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

# When detecting commands inside shell scripts, use this regex to match the
# beginning of the command rather than checking whether the command is at the
# beginning of a line.
const my $LEADING_PATTERN=>
'(?:(?:^|[`&;(|{])\s*|(?:if|then|do|while|!)\s+|env(?:\s+[[:alnum:]_]+=(?:\S+|\"[^"]*\"|\'[^\']*\'))*\s+)';
const my $LEADING_REGEX => qr/$LEADING_PATTERN/;

has seen_helper_commands => (is => 'rw', default => sub { {} });

sub visit_control_files {
    my ($self, $item) = @_;

    return
      unless $item->is_maintainer_script;

    return
      unless length $item->interpreter;

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

        if ($line
            =~ m{$LEADING_REGEX(?:/usr/bin/)?dpkg-maintscript-helper\s(\S+)}){

            my $command = $1;

            $self->seen_helper_commands->{$command} //= [];
            push(@{$self->seen_helper_commands->{$command}}, $item->name);
        }

    } continue {
        ++$position;
    }

    close $fd;

    return;
}

sub installable {
    my ($self) = @_;

    for my $command (keys %{$self->seen_helper_commands}) {

        # entering the loop means there is at least one member
        my @have = @{$self->seen_helper_commands->{$command} // [] };
        next
          unless @have;

        # dpkg-maintscript-helper(1) recommends the snippets are in all
        # maintainer scripts but they are not strictly required in prerm.
        my @wanted = qw{preinst postinst postrm};

        my $lc = List::Compare->new(\@wanted, \@have);

        my @missing = $lc->get_Lonly;

        $self->hint('missing-call-to-dpkg-maintscript-helper',
            $command, "[control/$_]")
          for @missing;
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
