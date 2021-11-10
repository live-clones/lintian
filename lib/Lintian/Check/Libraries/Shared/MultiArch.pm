# libraries/shared/multi-arch -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2018-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Libraries::Shared::MultiArch;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(none uniq);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has shared_libraries => (is => 'rw', default => sub { [] });

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ m{^ [^,]* \b ELF \b }x;

    return
      unless $item->file_info
      =~ m{(?: shared [ ] object | pie [ ] executable )}x;

    my @ldconfig_folders = @{$self->profile->architectures->ldconfig_folders};
    return
      if none { $item->dirname eq $_ } @ldconfig_folders;

    push(@{$self->shared_libraries}, $item->name);

    return;
}

sub installable {
    my ($self) = @_;

    $self->hint(
        'shared-library-is-multi-arch-foreign',
        (sort +uniq @{$self->shared_libraries}))
      if @{$self->shared_libraries}
      && $self->processable->fields->value('Multi-Arch') eq 'foreign';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
