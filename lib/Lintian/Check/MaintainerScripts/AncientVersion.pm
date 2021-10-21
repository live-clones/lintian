# maintainer-scripts/ancient-version -- lintian check script -*- perl -*-
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

package Lintian::Check::MaintainerScripts::AncientVersion;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use POSIX qw(strftime);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

# date --date="Sat, 6 Jul 2019 20:53:14 -0400" +%s
# https://lists.debian.org/debian-announce/2019/msg00003.html
const my $OLDSTABLE_RELEASE_EPOCH => 1_562_460_794;

# When detecting commands inside shell scripts, use this regex to match the
# beginning of the command rather than checking whether the command is at the
# beginning of a line.
const my $LEADING_PATTERN=>
'(?:(?:^|[`&;(|{])\s*|(?:if|then|do|while|!)\s+|env(?:\s+[[:alnum:]_]+=(?:\S+|\"[^"]*\"|\'[^\']*\'))*\s+)';
const my $LEADING_REGEX => qr/$LEADING_PATTERN/;

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

        for my $old_version (keys %{$self->old_versions}) {

            next
              if $old_version =~ /^\d+$/;

            if ($line
                =~m{$LEADING_REGEX(?:/usr/bin/)?dpkg\s+--compare-versions\s+.*\b\Q$old_version\E(?!\.)\b}
            ) {
                my $date
                  = strftime('%Y-%m-%d',
                    gmtime $self->old_versions->{$old_version});
                my $epoch
                  = strftime('%Y-%m-%d', gmtime $OLDSTABLE_RELEASE_EPOCH);

                $self->hint(
                    'maintainer-script-supports-ancient-package-version',
                    $old_version,"($date < $epoch)",
                    "[control/$item:$position]"
                );
            }
        }

    } continue {
        ++$position;
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
