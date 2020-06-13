# fields/required -- lintian check script -*- perl -*-
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

package Lintian::fields::required;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::Compare;
use Path::Tiny;

use constant AT => q{@};

use Moo;
use namespace::clean;

with 'Lintian::Check';

# policy 5.2
my @DEBIAN_CONTROL_SOURCE = qw(Source Maintainer Standards-Version);
my @DEBIAN_CONTROL_INSTALLABLE = qw(Package Architecture Description);

# policy 5.3
my @INSTALLATION_CONTROL
  = qw(Package Version Architecture Maintainer Description);

# policy 5.4
my @DSC = qw(Format Source Version Maintainer Standards-Version
  Checksums-Sha1 Checksums-Sha256 Files);

# policy 5.5
my @CHANGES = qw(Format Date Source Binary Architecture Version Distribution
  Maintainer Description Changes Checksums-Sha1 Checksums-Sha256 Files);

sub source {
    my ($self) = @_;

    my @control_fields = keys %{$self->processable->field};

    my $dscfile = path($self->processable->path)->basename;
    $self->tag_missing_fields($dscfile, \@DSC, \@control_fields);

    my $controlfile = 'debian/control';

    # look at d/control source paragraph
    my @source_fields = keys %{$self->processable->source_field};
    $self->tag_missing_fields($controlfile . AT . 'source',
        \@DEBIAN_CONTROL_SOURCE, \@source_fields);

    # look at d/control installable paragraphs
    my @installables = $self->processable->binaries;
    for my $installable (@installables) {
        my @installable_fields
          = keys %{$self->processable->binary_field($installable)};
        $self->tag_missing_fields(
            $controlfile . AT . $installable,
            \@DEBIAN_CONTROL_INSTALLABLE,
            \@installable_fields
        );
    }

    return;
}

sub installable {
    my ($self) = @_;

    my @control_fields = keys %{$self->processable->field};

    my $debfile = path($self->processable->path)->basename;
    $self->tag_missing_fields($debfile, \@INSTALLATION_CONTROL,
        \@control_fields);

    return;
}

sub changes {
    my ($self) = @_;

    my @control_fields = keys %{$self->processable->field};

    my $changesfile = path($self->processable->path)->basename;
    $self->tag_missing_fields($changesfile, \@CHANGES, \@control_fields);

    return;
}

sub tag_missing_fields {
    my ($self, $location, $required, $actual) = @_;

    # select fields for announcement
    my $missinglc = List::Compare->new($required, $actual);
    my @missing = $missinglc->get_Lonly;

    $self->tag('required-field', $location, $_) for @missing;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
