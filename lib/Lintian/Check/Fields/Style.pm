# fields/style -- lintian check script -*- perl -*-
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

package Lintian::Check::Fields::Style;

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
# and Priority are recommended not only in the source paragraph, but
# also in the binary paragraphs.

# in the author's opinion, however, it does not make sense to flag them
# there because the same two fields in the source paragraph provide the
# default for the fields in the binary package paragraph.

# moreover, such duplicate tags would then trigger the tag
# binary-control-field-duplicates-source elsewhere, which would be
# super confusing

sub source {
    my ($self) = @_;

    my @control_fields = $self->processable->fields->names;

    my $dscfile = path($self->processable->path)->basename;
    $self->check_style($dscfile, @control_fields);

    my $debian_control = $self->processable->debian_control;
    my $controlfile = 'debian/control';

    # look at d/control source paragraph
    my @source_fields = $debian_control->source_fields->names;
    $self->check_style($controlfile . $AT . 'source', @source_fields);

    # look at d/control installable paragraphs
    for my $installable ($debian_control->installables) {
        my @installable_fields
          = $debian_control->installable_fields($installable)->names;
        $self->check_style($controlfile . $AT . $installable,
            @installable_fields);
    }

    return;
}

sub installable {
    my ($self) = @_;

    my @control_fields = $self->processable->fields->names;

    my $debfile = path($self->processable->path)->basename;
    $self->check_style($debfile, @control_fields);

    return;
}

sub changes {
    my ($self) = @_;

    my @control_fields = $self->processable->fields->names;

    my $changesfile = path($self->processable->path)->basename;
    $self->check_style($changesfile, @control_fields);

    return;
}

sub check_style {
    my ($self, $location, @names) = @_;

    for my $name (@names) {

        # title-case the field name
        my $standard = lc $name;
        $standard =~ s/\b(\w)/\U$1/g;

        # capitalize up to three letters after an X, if followed by hyphen
        $standard =~ s/^(X[SBC]{1,3})-/\U$1-/i;

        $self->hint('cute-field', $location, "$name vs $standard")
          unless $name eq $standard;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
