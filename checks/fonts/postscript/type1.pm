# fonts/postscript/type1 -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2020 Felix Lechner
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

package Lintian::fonts::postscript::type1;

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::IPC::Run3 qw(safe_qx);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ m/PostScript Type 1 font program data/;

    my $output = safe_qx('t1disasm', $item->unpacked_path);
    my @lines = split(/\n/, $output);

    my $foundadobeline = 0;

    for my $line (@lines) {

        if ($foundadobeline) {
            if (
                $line =~ m{\A [%\s]*
                                   All\s*Rights\s*Reserved\.?\s*
                                       \Z}xsmi
            ) {
                $self->hint('license-problem-font-adobe-copyrighted-fragment',
                    $item);

                last;
            }
        }

        $foundadobeline = 1
          if $line =~ m{\A
                               [%\s]*Copyright\s*\(c\) \s*
                               19\d{2}[\-\s]19\d{2}\s*
                               Adobe\s*Systems\s*Incorporated\.?\s*\Z}xsmi;

        # If copy pasted from black book they are
        # copyright adobe a few line before the only
        # place where the startlock is documented is
        # in the black book copyrighted fragment
        if ($line =~ m/startlock\s*get\s*exec/) {

            $self->hint(
                'license-problem-font-adobe-copyrighted-fragment-no-credit',
                $item->name);

            last;
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
