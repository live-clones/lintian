# fonts/postscript/type1 -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Fonts::Postscript::Type1;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Encode qw(decode);
use Syntax::Keyword::Try;

use Lintian::IPC::Run3 qw(safe_qx);

use Moo;
use namespace::clean;

const my $SPACE => q{ };
const my $COLON => q{:};

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_type =~ m/PostScript Type 1 font program data/;

    my @command = ('t1disasm', $item->unpacked_path);
    my $bytes = safe_qx(@command);
    my $enc_warning = 'In file ' . $item->name . $COLON . $SPACE;

    my $output;
    try {
        # iso-8859-1 works too, but the Font 1 standard could be older
        $output = decode('cp1252', $bytes, Encode::FB_CROAK);

    } catch ($e) {
        if ($e =~ m{^cp1252 "\\x81" does not map to Unicode at .+}) {
            try {
                # sometimes, the file is utf8
                $output = decode('utf8', $bytes, Encode::FB_CROAK);
            } catch {
                die $enc_warning . $@;
            }
        } else {
            die $enc_warning . $@;
        }
    }

    my @lines = split(/\n/, $output);

    my $foundadobeline = 0;

    for my $line (@lines) {

        if ($foundadobeline) {
            if (
                $line =~ m{\A [%\s]*
                                   All\s*Rights\s*Reserved\.?\s*
                                       \Z}xsmi
            ) {
                $self->pointed_hint(
                    'license-problem-font-adobe-copyrighted-fragment',
                    $item->pointer);

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
#
# 2023-06-05: this check has been adjusted because
# Adobe's type hint code[1] (including Flex[2]) became
# open source[3] with an Apache-2.0 license[4] as
# committed on 2014-09-19, making that check a false
# positive[7].
#
# We continue to check for copyrighted code that is not
# available under an open source license from the origin
# publication,  "Adobe Type 1 Font Format"[5][6].
#
# [1] - https://github.com/adobe-type-tools/afdko/blob/2bf85cf44a64148353b24db17e0cc41ede5493b1/FDK/Tools/Programs/public/lib/source/t1write/t1write_hintothers.h
# [2] - https://github.com/adobe-type-tools/afdko/blob/2bf85cf44a64148353b24db17e0cc41ede5493b1/FDK/Tools/Programs/public/lib/source/t1write/t1write_flexothers.h
# [3] - https://www.mail-archive.com/debian-bugs-dist@lists.debian.org/msg1375813.html
# [4] - https://github.com/adobe-type-tools/afdko/blob/2bf85cf44a64148353b24db17e0cc41ede5493b1/LICENSE.txt
# [5] - https://adobe-type-tools.github.io/font-tech-notes/pdfs/T1_SPEC.pdf
# [6] - https://lccn.loc.gov/90042516
# [7] - https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1029555
        if ($line =~ m/UniqueID\s*6859/) {

            $self->pointed_hint(
                'license-problem-font-adobe-copyrighted-fragment-no-credit',
                $item->pointer);

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
