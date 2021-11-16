# languages/perl/core/provides -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2021 Felix Lechner
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

package Lintian::Check::Languages::Perl::Core::Provides;

use v5.20;
use warnings;
use utf8;

use Dpkg::Version qw(version_check);

use Lintian::Relation::Version qw(versions_compare);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub always {
    my ($self) = @_;

    my $fields = $self->processable->fields;

    return
      unless $fields->declares('Version');

    my $version = $fields->unfolded_value('Version');

    my $dversion = Dpkg::Version->new($version);
    return
      unless $dversion->is_valid;

    my ($epoch, $upstream, $debian)
      = ($dversion->epoch, $dversion->version, $dversion->revision);

    my $PERL_CORE_PROVIDES
      = $self->profile->load_data('fields/perl-provides', '\s+');

    my $name = $fields->value('Package');

    return
      unless $PERL_CORE_PROVIDES->recognizes($name);

    my $core_version = $PERL_CORE_PROVIDES->value($name);

    my $no_revision = "$epoch:$upstream";
    return
      unless version_check($no_revision);

    $self->hint('package-superseded-by-perl', "with $core_version")
      if versions_compare($core_version, '>=', $no_revision);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
