# fields/built-using -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright © 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::fields::built_using;

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::Relation qw(:constants);
use Lintian::Util qw($PKGNAME_REGEX $PKGVERSION_REGEX);

use constant {
    BUILT_USING_REGEX => qr/^$PKGNAME_REGEX \(= $PKGVERSION_REGEX\)$/,
};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub always {
    my ($self) = @_;

    my $processable = $self->processable;

    my $built_using = $processable->field('built-using');

    return
      unless defined $built_using;

    my $built_using_rel = Lintian::Relation->new($built_using);
    $built_using_rel->visit(
        sub {
            if ($_ !~ BUILT_USING_REGEX) {
                $self->tag('invalid-value-in-built-using-field', $_);
                return 1;
            }
            return 0;
        },
        VISIT_OR_CLAUSE_FULL | VISIT_STOP_FIRST_MATCH
    );

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
