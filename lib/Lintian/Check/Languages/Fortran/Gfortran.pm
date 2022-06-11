# languages/fortran/gfortran -- lintian check script -*- perl -*-

# Copyright (C) 2020 Felix Lechner
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

package Lintian::Check::Languages::Fortran::Gfortran;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

const my $NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    # file-info would be great, but files are zipped
    return
      unless $item->name =~ m{\.mod$};

    return
      unless $item->name =~ m{^usr/lib/};

    # do not look at flang, grub or libreoffice modules
    return
         if $item->name =~ m{/flang-\d+/}
      || $item->name =~ m{^usr/lib/grub}
      || $item->name =~ m{^usr/lib/libreoffice};

    return
         unless $item->is_file
      && $item->is_open_ok
      && $item->file_type =~ /\bgzip compressed\b/;

    my $module_version;

    open(my $fd, '<:gzip', $item->unpacked_path)
      or die encode_utf8(
        'Cannot open gz file ' . $item->unpacked_path . $NEWLINE);

    while (my $line = <$fd>) {
        next
          if $line =~ /^\s*$/;

        ($module_version) = ($line =~ /^GFORTRAN module version '(\d+)'/);
        last;
    }

    close $fd;

    unless (length $module_version) {
        $self->pointed_hint('gfortran-module-does-not-declare-version',
            $item->pointer);
        return;
    }

    my $depends = $self->processable->fields->value('Depends');
    $self->pointed_hint('missing-prerequisite-for-gfortran-module',
        $item->pointer)
      unless $depends =~ /\bgfortran-mod-$module_version\b/;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
