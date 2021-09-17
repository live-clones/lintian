# fields/urgency -- lintian check script -*- perl -*-

# Copyright © 2020 Felix Lechner
#
# This program is free software.  It is distributed under the terms of
# the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any
# later version.
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

package Lintian::Check::Fields::Urgency;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub changes {
    my ($self) = @_;

    return
      unless $self->processable->fields->declares('Urgency');

    my $urgency = $self->processable->fields->value('Urgency');

    # translate to lowercase
    my $lowercase = lc $urgency;

    # discard anything after the first word
    $lowercase =~ s/ .*//;

    $self->hint('bad-urgency-in-changes-file', $urgency)
      unless any { $lowercase =~ $_ } qw(low medium high critical emergency);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
