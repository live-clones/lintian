# fields/source -- lintian check script (rewrite) -*- perl -*-
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

package Lintian::fields::source;

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::Util qw($PKGNAME_REGEX);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $source = $processable->unfolded_field('source');

    # required in source packages, but dpkg-source already refuses to unpack
    # without this field (and fields depends on unpacked)
    return
      unless defined $source;

    my $filename = $processable->path;
    my ($base) = ($filename =~ m,(?:\a|/)([^/]+)$,);
    my ($stem) = ($base =~ /^([^_]+)_/);

    die "Source field does not match package name $source != $stem"
      if $source ne $stem;

    $self->tag('source-field-malformed', $source)
      if $source !~ /^[a-z0-9][-+\.a-z0-9]+\z/;

    return;
}

sub always {
    my ($self) = @_;

    my $type = $self->processable->type;
    my $processable = $self->processable;

    my $source = $processable->unfolded_field('source');

    # optional in binary packages
    return
      unless defined $source;

    return
      if $type eq 'source';

    $self->tag('source-field-malformed', $source)
      if $source !~ /^ $PKGNAME_REGEX
                         \s*
                         # Optional Version e.g. (1.0)
                         (?:\((?:\d+:)?(?:[-\.+:a-zA-Z0-9~]+?)(?:-[\.+a-zA-Z0-9~]+)?\))?\s*$/x;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
