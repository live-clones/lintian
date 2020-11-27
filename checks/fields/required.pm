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
# Binary and Description were removed, see Bug#963524
my @CHANGES = qw(Format Date Source Architecture Version Distribution
  Maintainer Changes Checksums-Sha1 Checksums-Sha256 Files);

sub source {
    my ($self) = @_;

    my $fields = $self->processable->fields;
    my $debian_control = $self->processable->debian_control;

    my @missing_dsc = grep { !$fields->exists($_) } @DSC;

    my $dscfile = path($self->processable->path)->basename;
    $self->hint('required-field', $dscfile, $_) for @missing_dsc;

    # look at d/control source paragraph
    my @missing_control_source
      = grep { !$debian_control->source_fields->exists($_) }
      @DEBIAN_CONTROL_SOURCE;

    my $controlfile = 'debian/control';
    $self->hint('required-field', $controlfile . AT . 'source', $_)
      for @missing_control_source;

    # look at d/control installable paragraphs
    for my $installable ($debian_control->installables) {

        my @missing_control_installable
          = grep {!$debian_control->installable_fields($installable)->exists($_)}
          @DEBIAN_CONTROL_INSTALLABLE;

        $self->hint('required-field', $controlfile . AT . $installable, $_)
          for @missing_control_installable;
    }

    return;
}

sub installable {
    my ($self) = @_;

    my $fields = $self->processable->fields;

    my @missing_installation_control
      = grep { !$fields->exists($_) } @INSTALLATION_CONTROL;

    my $debfile = path($self->processable->path)->basename;
    $self->hint('required-field', $debfile, $_)
      for @missing_installation_control;

    return;
}

sub changes {
    my ($self) = @_;

    my $fields = $self->processable->fields;

    my @missing_changes = grep { !$fields->exists($_) } @CHANGES;

    my $changesfile = path($self->processable->path)->basename;
    $self->hint('required-field', $changesfile, $_) for @missing_changes;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
