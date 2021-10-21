# debian/lintian-overrides -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::Check::Debian::LintianOverrides;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $file) = @_;

    my $ppkg = quotemeta($self->processable->name);

    # misplaced overrides
    if ($file->name =~ m{^usr/share/doc/$ppkg/override\.[lL]intian(?:\.gz)?$}
        || $file->name =~ m{^usr/share/lintian/overrides/$ppkg/.+}) {

        $self->hint('override-file-in-wrong-location', $file->name);

    } elsif ($file->name =~ m{^usr/share/lintian/overrides/(.+)/.+$}) {

        $self->hint('override-file-in-wrong-package', $file->name)
          unless $1 eq $self->processable->name;
    }

    return;
}

sub source {
    my ($self) = @_;

    $self->hint('old-source-override-location')
      if $self->processable->patched->resolve_path(
        'debian/source.lintian-overrides');

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
