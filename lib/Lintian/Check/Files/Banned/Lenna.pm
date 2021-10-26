# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 1999 Joey Hess
# Copyright © 2000 Sean 'Shaleh' Perry
# Copyright © 2002 Josip Rodin
# Copyright © 2007 Russ Allbery
# Copyright © 2013-2018 Bastien ROUCARIÈS
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Check::Files::Banned::Lenna;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# known bad files
has LENNA_BLACKLIST => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data(
            'files/banned/lenna/blacklist',
            qr/ \s* ~~ \s* /x,
            sub {
                my ($sha1, $sha256, $name, $link)
                  = split(/ \s* ~~ \s* /msx, $_[1]);

                return {
                    'sha1'   => $sha1,
                    'sha256' => $sha256,
                    'name'   => $name,
                    'link'   => $link,
                };
            });
    });

# known good files
has LENNA_WHITELIST => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('files/banned/lenna/whitelist');
    });

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
         unless $item->file_info =~ /\bimage\b/i
      || $item->file_info =~ /^Matlab v\d+ mat/i
      || $item->file_info =~ /\bbitmap\b/i
      || $item->file_info =~ /^PDF Document\b/i
      || $item->file_info =~ /^Postscript Document\b/i;

    return
      if $self->LENNA_WHITELIST->recognizes($item->md5sum);

    # Lena Söderberg image
    $self->hint('license-problem-non-free-img-lenna', $item->name)
      if $item->basename =~ / ( \b | _ ) lenn?a ( \b | _ ) /ix
      || $self->LENNA_BLACKLIST->recognizes($item->md5sum);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
