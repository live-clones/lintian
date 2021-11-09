# languages/php/composer -- lintian check script -*- perl -*-
#
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

package Lintian::Check::Languages::Php::Composer;

use v5.20;
use warnings;
use utf8;

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;
    my $source_fields = $control->source_fields;

    for my $field (
        qw(Build-Depends Build-Depends-Indep
        Build-Conflicts Build-Conflicts-Indep)
    ) {
        next
          unless $source_fields->declares($field);

        my $position = $source_fields->position($field);
        my $pointer = "(in source paragraph) [debian/control:$position]";

        my $raw = $source_fields->value($field);
        my $relation = Lintian::Relation->new->load($raw);

        my $condition = 'composer';

        $self->hint('composer-prerequisite', $field, $pointer)
          if $relation->satisfies($condition);
    }

    for my $installable ($control->installables) {
        my $installable_fields = $control->installable_fields($installable);

        for my $field (
            qw(Pre-Depends Depends Recommends Suggests Breaks
            Conflicts Provides Replaces Enhances)
        ) {
            next
              unless $installable_fields->declares($field);

            my $position = $installable_fields->position($field);
            my $pointer
              = "(in section for $installable) [debian/control:$position]";

            my $relation
              = $self->processable->binary_relation($installable, $field);

            my $condition = 'composer';

            $self->hint('composer-prerequisite', $field, $pointer)
              if $relation->satisfies($condition);
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
