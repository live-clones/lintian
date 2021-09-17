# fields/maintainer -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2020 Felix Lechner
# Copyright © 2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Fields::Maintainer;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    return
      unless $self->processable->fields->declares('Maintainer');

    my $maintainer = $self->processable->fields->value('Maintainer');

    my $is_list = $maintainer =~ /\@lists(?:\.alioth)?\.debian\.org\b/;

    $self->hint('no-human-maintainers')
      if $is_list && !$self->processable->fields->declares('Uploaders');

    return;
}

sub changes {
    my ($self) = @_;

    my $source = $self->group->source;
    return
      unless defined $source;

    my $changes_maintainer = $self->processable->fields->value('Maintainer');
    my $changes_distribution
      = $self->processable->fields->value('Distribution');

    my $source_maintainer = $source->fields->value('Maintainer');

    my $KNOWN_DISTS = $self->profile->load_data('changes-file/known-dists');

    # not for derivatives; https://wiki.ubuntu.com/DebianMaintainerField
    $self->hint('inconsistent-maintainer',
        $changes_maintainer . ' (changes vs. source) ' .$source_maintainer)
      if $changes_maintainer ne $source_maintainer
      && $KNOWN_DISTS->recognizes($changes_distribution);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
