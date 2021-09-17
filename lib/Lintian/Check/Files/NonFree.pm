# files/non-free -- lintian check script -*- perl -*-

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

package Lintian::Check::Files::NonFree;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $MD5SUM_DATA_FIELDS => 5;

sub _md5sum_based_lintian_data {
    my ($self, $filename) = @_;

    return $self->profile->load_data(
        $filename,
        qr/\s*\~\~\s*/,
        sub {
            my ($sha1, $sha256, $name, $reason, $link)
              = split(/ \s* ~~ \s* /msx, $_[1], $MD5SUM_DATA_FIELDS);

            die encode_utf8("Syntax error in $filename $.")
              if any { !defined } ($sha1, $sha256, $name, $reason, $link);

            return {
                'sha1'   => $sha1,
                'sha256' => $sha256,
                'name'   => $name,
                'reason' => $reason,
                'link'   => $link,
            };
        });
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

    my $nonfree = $self->NON_FREE_FILES->value($item->md5sum);
    if (defined $nonfree) {
        my $usualname = $nonfree->{'name'};
        my $reason = $nonfree->{'reason'};
        my $link = $nonfree->{'link'};

        $self->hint(
            'license-problem-md5sum-non-free-file',
            $item->name, "usual name is $usualname.",
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
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    # skip packages that declare non-free contents
    return
      if $self->processable->is_non_free;

    # non-free .swf files
    $self->hint('non-free-flash', $file->name)
      if any { $file->name =~ m{/$_} } @flash_nonfree;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
