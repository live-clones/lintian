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

package Lintian::fields::changed_by;

use v5.20;
use warnings;
use utf8;
use autodie;

use Email::Address::XS;
use List::MoreUtils qw(all);

use Lintian::Data;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $DERIVATIVE_CHANGED_BY= Lintian::Data->new('common/derivative-changed-by',
    qr/\s*~~\s*/, sub { $_[1]; });

sub changes {
    my ($self) = @_;

    # Changed-By is optional in Policy, but if set, must be
    # syntactically correct.  It's also used by dak.
    my $changed_by = $self->processable->field('Changed-By');
    return
      unless defined $changed_by;

    my $parsed;
    my @list = Email::Address::XS->parse($changed_by);
    $parsed = $list[0]
      if @list == 1;

    unless ($parsed->is_valid) {
        $self->tag('malformed-changed-by-field', $changed_by);
        return;
    }

    for my $regex ($DERIVATIVE_CHANGED_BY->all) {

        next
          if $parsed->format =~ /$regex/;

        my $explanation = $DERIVATIVE_CHANGED_BY->value($regex);
        $self->tag('changed-by-invalid-for-derivative',
            $parsed->format, "($explanation)");
    }

    unless (all { length } ($parsed->address, $parsed->user, $parsed->host)) {
        $self->tag('changed-by-address-malformed', $parsed->format);
        return;
    }

    $self->tag('changed-by-address-malformed',
        $parsed->address, 'not fully qualified')
      unless $parsed->host =~ /\./;

    $self->tag('changed-by-address-is-on-localhost',$parsed->address)
      if $parsed->host=~ /(?:localhost|\.localdomain|\.localnet)$/;

    unless (length $parsed->phrase) {
        $self->tag('changed-by-name-missing', $parsed->format);
        return;
    }

    $self->tag('changed-by-address-is-root-user', $parsed->format)
      if $parsed->user eq 'root' || $parsed->phrase eq 'root';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
