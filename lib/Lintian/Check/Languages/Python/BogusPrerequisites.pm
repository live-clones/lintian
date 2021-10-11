# languages/python/bogus-prerequisites -- lintian check script -*- perl -*-
#
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

package Lintian::Check::Languages::Python::BogusPrerequisites;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub installable {
    my ($self) = @_;

    $self->what_is_python($self->processable->source_name,
        qw{Depends Pre-Depends Recommends});

    return;
}

sub source {
    my ($self) = @_;

    $self->what_is_python($self->processable->name,
        qw{Build-Depends Build-Depends-Indep Build-Depends-Arch});

    return;
}

sub what_is_python {
    my ($self, $source, @fields) = @_;

    # see Bug#973011
    my @WHAT_IS_PYTHON = qw(
      python-is-python2:any
      python-dev-is-python2:any
      python-is-python3:any
      python-dev-is-python3:any
    );

    my %BOGUS_PREREQUISITES;

    unless ($source eq 'what-is-python') {

        for my $unwanted (@WHAT_IS_PYTHON) {

            $BOGUS_PREREQUISITES{$unwanted}
              = [grep {$self->processable->relation($_)->satisfies($unwanted)}
                  @fields];
        }
    }

    for my $unwanted (keys %BOGUS_PREREQUISITES) {

        $self->hint('bogus-python-prerequisite', $_, "(satisfies $unwanted)")
          for @{$BOGUS_PREREQUISITES{$unwanted}};
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
