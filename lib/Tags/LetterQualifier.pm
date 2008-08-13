# Copyright © 2008 Jordà Polo <jorda@ettin.org>
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

package Tags::LetterQualifier;

use strict;
use warnings;

use Term::ANSIColor;
use Tags;

my @codes = (
    [ 'W?', 'W ', 'W!' ], # wishlist (wild-guess, possible, certain)
    [ 'M?', 'M ', 'M!' ], # minor
    [ 'N?', 'N ', 'N!' ], # normal
    [ 'I?', 'I ', 'I!' ], # important
    [ 'S?', 'S ', 'S!' ], # serious
);

my @colors = (
    [  'green',   'green',    'cyan' ],
    [  'green',    'cyan',  'yellow' ],
    [   'cyan',  'yellow',  'yellow' ],
    [ 'yellow',     'red',     'red' ],
    [ 'yellow',     'red', 'magenta' ]
);

sub print_tag {
    my ( $pkg_info, $tag_info, $information ) = @_;

    my $code = Tags::get_tag_code($tag_info);
    $code = 'X' if exists $tag_info->{experimental};
    $code = 'O' if $tag_info->{overridden}{override};
    my $lq = Tags::get_tag_value($tag_info, \@codes);

    my $pkg = $pkg_info->{pkg};
    my $type = ($pkg_info->{type} ne 'binary') ? " $pkg_info->{type}" : '';

    my $tag = $tag_info->{tag};

    my $extra = @$information ? " @$information" : '';
    $extra = '' if $extra eq ' ';

    if ($Tags::color eq 'always' || ($Tags::color eq 'auto' && -t STDOUT)) {
        my $color = Tags::get_tag_value($tag_info, \@colors);
        $lq = colored($lq, $color);
        $tag = colored($tag, $color);
    }

    print "$code\[$lq\]: $pkg$type: $tag$extra\n";
}

1;

# vim: sw=4 sts=4 ts=4 et sr
