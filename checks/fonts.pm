# fonts -- lintian check script -*- perl -*-

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

package Lintian::fonts;

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::Util qw(drain_pipe);

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $FONT_PACKAGES = Lintian::Data->new('files/fonts', qr/\s++/);

sub files {
    my ($self, $file) = @_;

    if (   $file->is_file
        && $file->name =~ m,/([\w-]+\.(?:[to]tf|pfb|woff2?|eot)(?:\.gz)?)$,i) {

        my $font = lc $1;

        if (my $font_owner = $FONT_PACKAGES->value($font)) {
            $self->tag('duplicate-font-file', $file->name, 'also in',
                $font_owner)
              if (  $self->processable->name ne $font_owner
                and $self->processable->type ne 'udeb');

        } elsif ($self->processable->name !~ m/^(?:[ot]tf|t1|x?fonts)-/) {
            $self->tag('font-in-non-font-package', $file->name)
              unless $file->name =~ m,^usr/lib/R/site-library/,;
        }

        $self->tag('font-outside-font-dir', $file->name)
          unless $file->name =~ m,^usr/share/fonts/,
          or $file->name =~ m,^usr/lib/R/site-library/,;

        my $finfo = $file->file_info;
        if ($finfo =~ m/PostScript Type 1 font program data/) {
            my $absolute = $file->unpacked_path;
            my $foundadobeline = 0;
            open(my $t1pipe, '-|', 't1disasm', $absolute);
            while (my $line = <$t1pipe>) {
                if ($foundadobeline) {
                    if (
                        $line =~ m{\A [%\s]*
                                   All\s*Rights\s*Reserved\.?\s*
                                       \Z}xsmi
                    ) {
                        $self->tag(
                            'license-problem-font-adobe-copyrighted-fragment',
                            $file
                        );

                        last;
                    } else {
                        $foundadobeline = 0;
                    }
                }
                if (
                    $line =~ m{\A
                               [%\s]*Copyright\s*\(c\) \s*
                               19\d{2}[\-\s]19\d{2}\s*
                               Adobe\s*Systems\s*Incorporated\.?\s*\Z}xsmi
                ) {
                    $foundadobeline = 1;
                }
                # If copy pasted from black book they are
                # copyright adobe a few line before the only
                # place where the startlock is documented is
                # in the black book copyrighted fragment
                if ($line =~ m/startlock\s*get\s*exec/) {

                    $self->tag(
'license-problem-font-adobe-copyrighted-fragment-no-credit',
                        $file->name
                    );

                    last;
                }
            }
            drain_pipe($t1pipe);
            close($t1pipe);
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
