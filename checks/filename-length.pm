# filename-length -- lintian check script -*- perl -*-

# Copyright © 2011 Niels Thykier <niels@thykier.net>
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

package Lintian::filename_length;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

use constant FILENAME_LENGTH_LIMIT => 80;

# We could derive this from data/fields/architectures, but that
# contains things like kopensolaris-sparc64 and kfreebsd-sparc64,
# neither of which Debian officially supports.
use constant LONGEST_ARCHITECTURE => length 'kfreebsd-amd64';

sub always {
    my ($self) = @_;

    my $pkg = $self->package;
    my $type = $self->type;
    my $processable = $self->processable;

    # pkg_version(_arch)?.type
    # - here we pay for length of "name_version"
    my $len = length($pkg) + length($processable->version) + 1;
    my $extra;

    # Skip auto-generated packages (dbgsym)
    return
      if ($type eq 'binary' or $type eq 'udeb')
      and $processable->is_pkg_class('auto-generated');

    if ($type eq 'binary' || $type eq 'source'){
        # Here we add length .deb / .dsc (in both cases +4)
        $len += 4;
    } else {
        # .udeb, that's a +5
        $len += 5;
    }

    if ($type ne 'source') {
        # non-src pkgs have architecture as well
        if ($processable->architecture ne 'all'){
            my $real = $len + 1 + length($processable->architecture);
            $len  += 1 + LONGEST_ARCHITECTURE;
            $extra = "$real ($len)";
        } else {
            # _all has length 4
            $len += 4;
        }
    }
    $extra = $len unless defined $extra;

    $self->tag('package-has-long-file-name',"$extra > ". FILENAME_LENGTH_LIMIT)
      if $len > FILENAME_LENGTH_LIMIT;

    return if $type ne 'source';

    # Reset to work with elements of the dsc file.
    $len = 0;

    foreach my $entry (split /\n/, $processable->field('files', '')){
        my $filename;
        my $flen;

        # trim both ends
        $entry =~ s/^\s+|\s+$//g;

        next unless $entry;
        (undef, undef, $filename) = split /\s++/, $entry;
        next unless $filename;
        $flen = length($filename);
        $len = $flen if ($flen > $len);
    }

    if ($len > FILENAME_LENGTH_LIMIT){
        $self->tag('source-package-component-has-long-file-name',
            "$len > " . FILENAME_LENGTH_LIMIT);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
