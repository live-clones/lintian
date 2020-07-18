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

package Lintian::fields::maintainer;

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::Data;

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $KNOWN_BOUNCE_ADDRESSES = Lintian::Data->new('fields/bounce-addresses');
my $KNOWN_DISTS = Lintian::Data->new('changes-file/known-dists');

sub source {
    my ($self) = @_;

    my $maintainer = $self->processable->fields->value('Maintainer');
    return
      unless defined $maintainer;

    my $is_list = $maintainer =~ /\@lists(?:\.alioth)?\.debian\.org\b/;

    $self->tag('no-human-maintainers')
      if $is_list && !defined $self->processable->fields->value('Uploaders');

    return;
}

sub changes {
    my ($self) = @_;

    my $source = $self->group->source;
    return
      unless defined $source;

    my $changes_maintainer = $self->processable->fields->value('Maintainer')
      // EMPTY;
    my $changes_distribution
      = $self->processable->fields->value('Distribution')// EMPTY;

    my $source_maintainer = $source->fields->value('Maintainer') // EMPTY;

    # not for derivatives; https://wiki.ubuntu.com/DebianMaintainerField
    $self->tag('inconsistent-maintainer',
        $changes_maintainer . ' (changes vs. source) ' .$source_maintainer)
      unless $changes_maintainer eq $source_maintainer
      || !$KNOWN_DISTS->known($changes_distribution);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
