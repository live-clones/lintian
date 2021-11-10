# libraries/shared/trigger/ldconfig -- lintian check script -*- perl -*-

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

package Lintian::Check::Libraries::Shared::Trigger::Ldconfig;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any uniq);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has soname_by_filename => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %soname_by_filename;
        for my $item (@{$self->processable->installed->sorted_list}) {

            $soname_by_filename{$item->name}= $item->elf->{SONAME}[0]
              if exists $item->elf->{SONAME};
        }

        return \%soname_by_filename;
    });

has must_call_ldconfig => (is => 'rw', default => sub { [] });

sub visit_installed_files {
    my ($self, $item) = @_;

    my $resolved_name = $item->name;
    $resolved_name = $item->link_normalized
      if length $item->link;

    # Installed in a directory controlled by the dynamic
    # linker?  We have to strip off directories named for
    # hardware capabilities.
    # yes! so postinst must call ldconfig
    push(@{$self->must_call_ldconfig}, $resolved_name)
      if exists $self->soname_by_filename->{$resolved_name}
      && $self->needs_ldconfig($item);

    return;
}

sub installable {
    my ($self) = @_;

    # determine if the package had an ldconfig trigger
    my $triggers = $self->processable->control->resolve_path('triggers');

    my $we_trigger_ldconfig = 0;
    $we_trigger_ldconfig = 1
      if defined $triggers
      && $triggers->decoded_utf8
      =~ /^ \s* activate-noawait \s+ ldconfig \s* $/mx;

    $self->hint('package-has-unnecessary-activation-of-ldconfig-trigger')
      if !@{$self->must_call_ldconfig}
      && $we_trigger_ldconfig
      && $self->processable->type ne 'udeb';

    $self->hint('lacks-ldconfig-trigger',
        (sort +uniq @{$self->must_call_ldconfig}))
      if @{$self->must_call_ldconfig}
      && !$we_trigger_ldconfig
      && $self->processable->type ne 'udeb';

    return;
}

sub needs_ldconfig {
    my ($self, $file) = @_;

   # Libraries that should only be used in the presence of certain capabilities
   # may be located in subdirectories of the standard ldconfig search path with
   # one of the following names.
    my $HWCAP_DIRS = $self->profile->load_data('shared-libs/hwcap-dirs');
    my @ldconfig_folders = @{$self->profile->architectures->ldconfig_folders};

    my $dirname = $file->dirname;
    my $encapsulator;
    do {
        $dirname =~ s{ ([^/]+) / $}{}x;
        $encapsulator = $1;

    } while ($encapsulator && $HWCAP_DIRS->recognizes($encapsulator));

    $dirname .= "$encapsulator/" if $encapsulator;

    # yes! so postinst must call ldconfig
    return 1
      if any { $dirname eq $_ } @ldconfig_folders;

    return 0;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
