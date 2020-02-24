# mailcap -- lintian check script -*- perl -*-

# Copyright © 2019 Felix Lechner
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

package Lintian::mailcap;

use strict;
use warnings;
use autodie qw(open);

use List::MoreUtils qw(uniq);
use Text::Balanced qw(extract_delimited extract_multiple);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COLON => q{:};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub files {
    my ($self, $file) = @_;

    return
      unless $file->name =~ m{^usr/lib/mime/packages/};

    return
      unless $file->is_file && $file->is_open_ok;

    open(my $fd, '<', $file->unpacked_path);

    my @continuation;

    while (<$fd>) {

        unless (@continuation) {
            # skip blank lines
            next
              if /^\s*$/;

            # skip comments
            next
              if /^\s*#/;
        }

        # continuation line
        if (s/\\$//) {
            push(@continuation, {string => $_, position => $.});
            next;
        }

        push(@continuation, {string => $_, position => $.});

        my $line = EMPTY;
        $line .= $_->{string}for @continuation;

        my $position = $continuation[0]->{position};

        my @quoted
          = extract_multiple($line,
            [sub { extract_delimited($_[0], q{"'}, '[^\'"]*') }],
            undef, 1);

        my @placeholders = uniq grep { /\%s/ } @quoted;

        $self->tag(
            'quoted-placeholder-in-mailcap-entry',
            $file->name . COLON . $position,
            @placeholders
        )if @placeholders;

        @continuation = ();
    }

    close($fd);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
