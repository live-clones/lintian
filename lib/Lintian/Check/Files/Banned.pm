# files/banned -- lintian check script -*- perl -*-
#
# based on debhelper check,
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Files::Banned;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any);
use Unicode::UTF8 qw(encode_utf8);

const my $MD5SUM_DATA_FIELDS => 5;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub _md5sum_based_lintian_data {
    my ($self, $filename) = @_;

    my $data = $self->data->load($filename,qr/\s*\~\~\s*/);

    my %md5sum_data;

    for my $md5sum ($data->all) {

        my $value = $data->value($md5sum);

        my ($sha1, $sha256, $name, $reason, $link)
          = split(/ \s* ~~ \s* /msx, $value, $MD5SUM_DATA_FIELDS);

        die encode_utf8("Syntax error in $filename $.")
          if any { !defined } ($sha1, $sha256, $name, $reason, $link);

        $md5sum_data{$md5sum} = {
            'sha1'   => $sha1,
            'sha256' => $sha256,
            'name'   => $name,
            'reason' => $reason,
            'link'   => $link,
        };
    }

    return \%md5sum_data;
}

has NON_DISTRIBUTABLE_FILES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->_md5sum_based_lintian_data(
            'cruft/non-distributable-files');
    }
);

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    my $banned = $self->NON_DISTRIBUTABLE_FILES->{$item->md5sum};
    if (defined $banned) {
        my $usualname = $banned->{'name'};
        my $reason = $banned->{'reason'};
        my $link = $banned->{'link'};

        $self->pointed_hint(
            'license-problem-md5sum-non-distributable-file',
            $item->pointer, "usual name is $usualname.",
            $reason, "See also $link."
        );
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
