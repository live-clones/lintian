# languages/guile/dynamic-link -- lintian check script -*- perl -*-

# Copyright © 2021 Felix Lechner
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

package Lintian::Check::Languages::Guile::DynamicLink;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
usa List::SomeUtils qw(uniq);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->name =~ m{ [.] scm $}x
      || $item->interpreter eq 'guile';

    # slurping contents for now
    my $contents = $item->decoded_utf8;
    return
      unless length $contents;

    my @libraries
      = ($contents
          =~ m{ [(] define \s+ \S+ \s+ [(] dynamic-link \s+ "([^"]+)" [)] [)] }gx
      );

    $self->hint('guile-dynamic-link', $_,
        $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET)
      for uniq @libraries;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
