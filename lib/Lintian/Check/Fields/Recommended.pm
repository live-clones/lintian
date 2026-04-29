# fields/recommended -- lintian check script -*- perl -*-
#
# Copyright (C) 2020-2021 Felix Lechner
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Fields::Recommended;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Path::Tiny;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $AT => q{@};

# policy section 5.2 states unequivocally that the two fields Section
# is recommended not only in the source paragraph, but
# also in the binary paragraphs in source debian/control.

# in the author's opinion, however, it does not make sense to flag them
# there because the same two fields in the source paragraph provide the
# default for the fields in the binary package paragraph.

# moreover, such duplicate tags would then trigger the tag
# binary-control-field-duplicates-source elsewhere, which would be
# super confusing

# policy 5.2
my @DEBIAN_CONTROL_SOURCE = qw(Section);
my @DEBIAN_CONTROL_INSTALLABLE = qw(); # Section

# policy 5.3
my @INSTALLATION_CONTROL = qw(Section Priority);

# policy 5.4
my @DSC = qw(Package-List);

# policy 5.5
my @CHANGES = qw(Urgency);

sub source {
    my ($self) = @_;

    my $fields = $self->processable->fields;
    my @missing_dsc = grep { !$fields->declares($_) } @DSC;

    my $dscfile = path($self->processable->path)->basename;
    $self->hint('recommended-field', $dscfile, $_) for @missing_dsc;

    my $debian_control = $self->processable->debian_control;
    my $control_item = $debian_control->item;

    # look at d/control source paragraph
    my $source_fields = $debian_control->source_fields;

    my @missing_control_source
      = grep { !$source_fields->declares($_) }@DEBIAN_CONTROL_SOURCE;

    my $source_position = $source_fields->position;
    my $source_pointer = $control_item->pointer($source_position);

    $self->pointed_hint('recommended-field', $source_pointer,
        '(in section for source)', $_)
      for @missing_control_source;

    # look at d/control installable paragraphs
    for my $installable ($debian_control->installables) {

        my $installable_fields
          = $debian_control->installable_fields($installable);

        my @missing_control_installable
          = grep {!$installable_fields->declares($_)}
          @DEBIAN_CONTROL_INSTALLABLE;

        my $installable_position = $installable_fields->position;
        my $installable_pointer= $control_item->pointer($installable_position);

        $self->pointed_hint('recommended-field', $installable_pointer,
            "(in section for $installable)", $_)
          for @missing_control_installable;
    }

    return;
}

sub installable {
    my ($self) = @_;

    my $fields = $self->processable->fields;

    my @missing_installation_control
      = grep { !$fields->declares($_) } @INSTALLATION_CONTROL;

    my $debfile = path($self->processable->path)->basename;
    $self->hint('recommended-field', $debfile, $_)
      for @missing_installation_control;

    return;
}

sub changes {
    my ($self) = @_;

    my $fields = $self->processable->fields;

    my @missing_changes = grep { !$fields->declares($_) } @CHANGES;

    my $changesfile = path($self->processable->path)->basename;
    $self->hint('recommended-field', $changesfile, $_) for @missing_changes;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
