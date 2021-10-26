# archive/file/name/length -- lintian check script -*- perl -*-

# Copyright © 2011 Niels Thykier <niels@thykier.net>
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

package Lintian::Check::Archive::File::Name::Length;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };

const my $FILENAME_LENGTH_LIMIT => 80;

# We could derive this from data/fields/architectures, but that
# contains things like kopensolaris-sparc64 and kfreebsd-sparc64,
# neither of which Debian officially supports.
const my $LONGEST_ARCHITECTURE => length 'kfreebsd-amd64';

sub always {
    my ($self) = @_;

    # Skip auto-generated packages (dbgsym)
    return
      if $self->processable->fields->declares('Auto-Built-Package');

    my $basename = basename($self->processable->path);

    my $adjusted_length
      = length($basename)
      - length($self->processable->architecture)
      + $LONGEST_ARCHITECTURE;

    $self->hint('package-has-long-file-name', $basename)
      if $adjusted_length > $FILENAME_LENGTH_LIMIT;

    return;
}

sub source {
    my ($self) = @_;

    my @lines = $self->processable->fields->trimmed_list('Files', qr/\n/);

    for my $line (@lines) {

        my (undef, undef, $name) = split($SPACE, $line);
        next
          unless length $name;

        $self->hint('source-package-component-has-long-file-name', $name)
          if length $name > $FILENAME_LENGTH_LIMIT;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
