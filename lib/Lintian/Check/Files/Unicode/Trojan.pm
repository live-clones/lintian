# files/unicode/trojan -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2019 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Files::Unicode::Trojan;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Unicode::UTF8 qw(decode_utf8 valid_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $DOUBLE_QUOTE => q{"};

const my %NAMES_BY_CHARACTER => (
    qq{\N{ARABIC LETTER MARK}} => 'ARABIC LETTER MARK', # U+061C
    qq{\N{LEFT-TO-RIGHT MARK}} => 'LEFT-TO-RIGHT MARK', # U+200E
    qq{\N{RIGHT-TO-LEFT MARK}} => 'RIGHT-TO-LEFT MARK', # U+200F
    qq{\N{LEFT-TO-RIGHT EMBEDDING}} => 'LEFT-TO-RIGHT EMBEDDING', # U+202A
    qq{\N{RIGHT-TO-LEFT EMBEDDING}} => 'RIGHT-TO-LEFT EMBEDDING', # U+202B
    qq{\N{POP DIRECTIONAL FORMATTING}} =>'POP DIRECTIONAL FORMATTING', # U+202C
    qq{\N{LEFT-TO-RIGHT OVERRIDE}} => 'LEFT-TO-RIGHT OVERRIDE', # U+202D
    qq{\N{RIGHT-TO-LEFT OVERRIDE}} => 'RIGHT-TO-LEFT OVERRIDE', # U+202E
    qq{\N{LEFT-TO-RIGHT ISOLATE}} => 'LEFT-TO-RIGHT ISOLATE', # U+2066
    qq{\N{RIGHT-TO-LEFT ISOLATE}} => 'RIGHT-TO-LEFT ISOLATE', # U+2067
    qq{\N{FIRST STRONG ISOLATE}} => 'FIRST STRONG ISOLATE', # U+2068
    qq{\N{POP DIRECTIONAL ISOLATE}} => 'POP DIRECTIONAL ISOLATE', # U+2069
);

sub visit_patched_files {
    my ($self, $item) = @_;

    $self->check_for_trojan($item);

    return;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    $self->check_for_trojan($item);

    return;
}

sub check_for_trojan {
    my ($self, $item) = @_;

    if (valid_utf8($item->name)) {

        my $decoded_name = decode_utf8($item->name);

        # all file names
        for my $character (keys %NAMES_BY_CHARACTER) {

            $self->hint(
                'unicode-trojan',
                'File name',
                sprintf('U+%vX', $character),
                $DOUBLE_QUOTE. $NAMES_BY_CHARACTER{$character}. $DOUBLE_QUOTE,
                $item->name
            ) if $decoded_name =~ m{\Q$character\E};
        }
    }

    return
      unless $item->is_script;

    # slurping contents for now in hope of speed
    my $contents = $item->decoded_utf8;
    return
      unless length $contents;

    for my $character (keys %NAMES_BY_CHARACTER) {

        $self->hint(
            'unicode-trojan',
            'Contents',
            sprintf('U+%vX', $character),
            $DOUBLE_QUOTE . $NAMES_BY_CHARACTER{$character} . $DOUBLE_QUOTE,
            $item->name
        )if $contents =~ m{\Q$character\E};
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
