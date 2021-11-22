# fonts -- lintian check script -*- perl -*-

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

package Lintian::Check::Fonts;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->basename
      =~ m{ [\w-]+ [.] (?:[to]tf | pfb | woff2? | eot) (?:[.]gz)? $}ix;

    my $font = $item->basename;

    my $FONT_PACKAGES = $self->profile->fonts;

    my @declared_shippers = $FONT_PACKAGES->installed_by($font);

    if (@declared_shippers) {

        # Fonts in xfonts-tipa are really shipped by tipa.
        my @renamed
          = map { $_ eq 'xfonts-tipa' ? 'tipa' : $_ } @declared_shippers;

        my $list
          = $LEFT_PARENTHESIS
          . join($SPACE, (sort @renamed))
          . $RIGHT_PARENTHESIS;

        $self->hint('duplicate-font-file', $item->name, 'also in', $list)
          unless (any { $_ eq $self->processable->name } @renamed)
          || $self->processable->type eq 'udeb';

    } else {
        unless ($item->name =~ m{^usr/lib/R/site-library/}) {

            $self->hint('font-in-non-font-package', $item->name)
              unless $self->processable->name =~ m/^(?:[ot]tf|t1|x?fonts)-/;

            $self->hint('font-outside-font-dir', $item->name)
              unless $item->name =~ m{^usr/share/fonts/};
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
