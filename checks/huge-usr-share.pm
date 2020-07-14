# huge-usr-share -- lintian check script -*- perl -*-

# Copyright © 2004 Jeroen van Wolffelaar <jeroen@wolffelaar.nl>
# Copyright © 2018 Chris Lamb <lamby@debian.org>
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

package Lintian::huge_usr_share;

use v5.20;
use warnings;
use utf8;
use autodie;

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

# Threshold in kB of /usr/share to trigger this warning.  Consider that the
# changelog alone can be quite big, and cannot be moved away.
my $THRESHOLD_SIZE_SOFT = 4096;
my $THRESHOLD_SIZE_HARD = 8192;
my $THRESHOLD_PERCENTAGE = 50;

has total_size => (is => 'rwp', default => 0);
has usrshare_size => (is => 'rwp', default => 0);

sub files {
    my ($self, $file) = @_;

    return
      unless $file->is_regular_file;

    # space taken up by package
    $self->_set_total_size($self->total_size + $file->size);

    # space taken up in /usr/share.
    $self->_set_usrshare_size($self->usrshare_size + $file->size)
      if $file =~ m,usr/share/,;

    return;
}

sub breakdown {
    my ($self) = @_;

    # skip architecture-dependent packages.
    my $arch = $self->processable->fields->value('Architecture') // EMPTY;
    return
      if $arch eq 'all';

    # meaningless; prevents division by zero
    return
      unless $self->total_size > 0;

    # convert the totals to kilobytes.
    my $size = sprintf('%.0f', $self->total_size / 1024);
    my $size_usrshare = sprintf('%.0f', $self->usrshare_size / 1024);
    my $percentage
      = sprintf('%.0f', 100 * $self->usrshare_size / $self->total_size);

    $self->tag(
        'arch-dep-package-has-big-usr-share',
        "${size_usrshare}kB $percentage%"
      )
      if ( $percentage > $THRESHOLD_PERCENTAGE
        && $size_usrshare > $THRESHOLD_SIZE_SOFT)
      || $size_usrshare > $THRESHOLD_SIZE_HARD;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
