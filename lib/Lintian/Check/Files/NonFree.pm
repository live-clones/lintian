# files/non-free -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 1999 Joey Hess
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2002 Josip Rodin
# Copyright (C) 2007 Russ Allbery
# Copyright (C) 2013-2018 Bastien ROUCARIÈS
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

package Lintian::Check::Files::NonFree;

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

has NON_FREE_FILES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->_md5sum_based_lintian_data('cruft/non-free-files');
    });

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # skip packages that declare non-free contents
    return
      if $self->processable->is_non_free;

    my $nonfree = $self->NON_FREE_FILES->{$item->md5sum};
    if (defined $nonfree) {
        my $usualname = $nonfree->{'name'};
        my $reason = $nonfree->{'reason'};
        my $link = $nonfree->{'link'};

        $self->pointed_hint(
            'license-problem-md5sum-non-free-file',
            $item->pointer, "usual name is $usualname.",
            $reason, "See also $link."
        );
    }

    return;
}

# A list of known non-free flash executables
my @flash_nonfree = (
    qr/(?i)dewplayer(?:-\w+)?\.swf$/,
    qr/(?i)(?:mp3|flv)player\.swf$/,
    # Situation needs to be clarified:
    #    qr,(?i)multipleUpload\.swf$,
    #    qr,(?i)xspf_jukebox\.swf$,
);

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # skip packages that declare non-free contents
    return
      if $self->processable->is_non_free;

    # non-free .swf files
    $self->pointed_hint('non-free-flash', $item->pointer)
      if any { $item->name =~ m{/$_} } @flash_nonfree;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
