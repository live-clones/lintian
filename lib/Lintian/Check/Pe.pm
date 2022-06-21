# pe -- lintian check script -*- perl -*-

# Copyright (C) 2017-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Pe;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Syntax::Keyword::Try;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };

const my $MAIN_HEADER => 0x3c;
const my $MAIN_HEADER_LENGTH_WORD_SIZE => 4;
const my $OPTIONAL_HEADER => 0x18;
const my $DLL_CHARACTERISTICS => 0x46;
const my $ASLR_FLAG => 0x40;
const my $DEP_NX_FLAG => 0x100;
const my $UNSAFE_SEH_FLAG => 0x400;

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_type =~ /^PE32\+? executable/;

    return
      unless $item->is_open_ok;

    my $buf;
    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    try {
        # offset to main header
        seek($fd, $MAIN_HEADER, 0)
          or die encode_utf8("seek: $!");

        read($fd, $buf, $MAIN_HEADER_LENGTH_WORD_SIZE)
          or die encode_utf8("read: $!");

        my $pe_offset = unpack('V', $buf);

        # 0x18 is index to "Optional Header"; 0x46 to DLL Characteristics
        seek($fd, $pe_offset + $OPTIONAL_HEADER + $DLL_CHARACTERISTICS, 0)
          or die encode_utf8("seek: $!");

        # get DLLCharacteristics value
        read($fd, $buf, 2)
          or die encode_utf8("read: $!");

    } catch {
        die $@;
    }

    my $characteristics = unpack('v', $buf);
    my %features = (
        'ASLR' => $characteristics & $ASLR_FLAG,
        'DEP/NX' => $characteristics & $DEP_NX_FLAG,
        'SafeSEH' => ~$characteristics & $UNSAFE_SEH_FLAG,  # note negation
    );

    # Don't check for the x86-specific "SafeSEH" feature for code
    # that is JIT-compiled by the Mono runtime. (#926334)
    delete $features{'SafeSEH'}
      if $item->file_type =~ / Mono\/.Net assembly, /;

    my @missing = grep { !$features{$_} } sort keys %features;

    $self->pointed_hint('portable-executable-missing-security-features',
        $item->pointer,join($SPACE, @missing))
      if scalar @missing;

    close $fd;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
