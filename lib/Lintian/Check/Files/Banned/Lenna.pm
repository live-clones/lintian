# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 1999 Joey Hess
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2002 Josip Rodin
# Copyright (C) 2007 Russ Allbery
# Copyright (C) 2013-2018 Bastien ROUCARIES
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020-2021 Felix Lechner
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

        my %blacklist;

        my $data = $self->data->load('files/banned/lenna/blacklist',
            qr/ \s* ~~ \s* /x);

        for my $md5sum ($data->all) {

            my $value = $data->value($md5sum);

            my ($sha1, $sha256, $name, $link)
              = split(/ \s* ~~ \s* /msx, $value);

            $blacklist{$md5sum} = {
                'sha1'   => $sha1,
                'sha256' => $sha256,
                'name'   => $name,
                'link'   => $link,
            };
        }

        return \%blacklist;
    }
);

# known good files
has LENNA_WHITELIST => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->data->load('files/banned/lenna/whitelist');
    }
);

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_type =~ /\bimage\b/i
      || $item->file_type =~ /^Matlab v\d+ mat/i
      || $item->file_type =~ /\bbitmap\b/i
      || $item->file_type =~ /^PDF Document\b/i
      || $item->file_type =~ /^Postscript Document\b/i;

    return
      if $self->LENNA_WHITELIST->recognizes($item->md5sum);

    # Lena Soderberg image
    $self->pointed_hint('license-problem-non-free-img-lenna', $item->pointer)
      if $item->basename =~ / ( \b | _ ) lenn?a ( \b | _ ) /ix
      || exists $self->LENNA_BLACKLIST->{$item->md5sum};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
