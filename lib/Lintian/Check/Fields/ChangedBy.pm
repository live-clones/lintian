# changed-by -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2017-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Fields::ChangedBy;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub changes {
    my ($self) = @_;

    # Changed-By is optional in Policy, but if set, must be
    # syntactically correct.  It's also used by dak.
    return
      unless $self->processable->fields->declares('Changed-By');

    my $changed_by = $self->processable->fields->value('Changed-By');

    my $DERIVATIVE_CHANGED_BY
      = $self->profile->load_data('common/derivative-changed-by',
        qr/\s*~~\s*/, sub { $_[1]; });

    for my $regex ($DERIVATIVE_CHANGED_BY->all) {

        next
          if $changed_by =~ /$regex/;

        my $explanation = $DERIVATIVE_CHANGED_BY->value($regex);
        $self->hint('changed-by-invalid-for-derivative',
            $changed_by, "($explanation)");
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
