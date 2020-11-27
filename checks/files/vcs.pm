# files/vcs -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files::vcs;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $COMPRESS_FILE_EXTENSIONS
  = Lintian::Data->new('files/compressed-file-extensions',
    qr/\s++/,sub { return qr/\Q$_[0]\E/ });

# an OR (|) regex of all compressed extension
my $COMPRESS_FILE_EXTENSIONS_OR_ALL = sub { qr/(:?$_[0])/ }
  ->(
    join('|',
        map {$COMPRESS_FILE_EXTENSIONS->value($_) }
          $COMPRESS_FILE_EXTENSIONS->all));

# vcs control files
my $VCS_FILES = Lintian::Data->new(
    'files/vcs-control-files',
    qr/\s++/,
    sub {
        my $regexp = $_[0];
        $regexp=~ s/\$[{]COMPRESS_EXT[}]/$COMPRESS_FILE_EXTENSIONS_OR_ALL/g;
        return qr/(?:$regexp)/x;
    });

# an OR (|) regex of all vcs files
my $VCS_FILES_OR_ALL = sub { qr/(?:$_[0])/ }
  ->(join('|', map { $VCS_FILES->value($_) } $VCS_FILES->all));

sub visit_installed_files {
    my ($self, $file) = @_;

    if ($file->is_file) {

        if (    $file->name =~ m,$VCS_FILES_OR_ALL,
            and $file->name !~ m,^usr/share/cargo/registry/,) {
            $self->hint('package-contains-vcs-control-file', $file->name);
        }

        if ($file->name =~ m/svn-commit.*\.tmp$/) {
            $self->hint('svn-commit-file-in-package', $file->name);
        }

        if ($file->name =~ m/svk-commit.+\.tmp$/) {
            $self->hint('svk-commit-file-in-package', $file->name);
        }

    }elsif ($file->is_dir) {

        if ($file->name =~ m,/CVS/?$,) {
            $self->hint('package-contains-vcs-control-dir', $file->name);
        }

        if ($file->name =~ m,/\.(?:svn|bzr|git|hg)/?$,) {
            $self->hint('package-contains-vcs-control-dir', $file->name);
        }

        if (   ($file->name =~ m,/\.arch-ids/?$,)
            || ($file->name =~ m,/\{arch\}/?$,)) {
            $self->hint('package-contains-vcs-control-dir', $file->name);
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
