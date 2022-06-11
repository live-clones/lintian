# mailcap -- lintian check script -*- perl -*-

# Copyright (C) 2019 Felix Lechner
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

package Lintian::Check::Mailcap;

use v5.20;
use warnings;
use utf8;
use autodie qw(open);

use Const::Fast;
use List::SomeUtils qw(uniq);
use Text::Balanced qw(extract_delimited extract_multiple);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->name =~ m{^usr/lib/mime/packages/};

    return
      unless $item->is_file && $item->is_open_ok;

    open(my $fd, '<', $item->unpacked_path);

    my @continuation;

    my $position = 1;
    while (my $line = <$fd>) {

        unless (@continuation) {
            # skip blank lines
            next
              if $line =~ /^\s*$/;

            # skip comments
            next
              if $line =~ /^\s*#/;
        }

        # continuation line
        if ($line =~ s/\\$//) {
            push(@continuation, {string => $line, position => $position});
            next;
        }

        push(@continuation, {string => $line, position => $position});

        my $assembled = $EMPTY;
        $assembled .= $_->{string} for @continuation;

        my $start_position = $continuation[0]->{position};

        my @quoted
          = extract_multiple($assembled,
            [sub { extract_delimited($_[0], q{"'}, '[^\'"]*') }],
            undef, 1);

        my @placeholders = uniq grep { /\%s/ } @quoted;

        $self->pointed_hint(
            'quoted-placeholder-in-mailcap-entry',
            $item->pointer($start_position),
            @placeholders
        )if @placeholders;

        @continuation = ();

    } continue {
        ++$position;
    }

    close $fd;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
