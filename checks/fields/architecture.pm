# fields/architecture -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
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

package Lintian::fields::architecture;

use strict;
use warnings;
use autodie;

use Lintian::Architecture qw(:all);

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

has architecture => (is => 'rwp', default => EMPTY);
has have_r_package_not_arch_all => (is => 'rwp', default => 0);

sub setup {
    my ($self) = @_;

    my $unsplit = $self->info->unfolded_field('architecture');

    return
      unless defined $unsplit;

    my @list = split(m/ /o, $unsplit);

    return
      unless @list;

    $self->_set_architecture($list[0]);

    return;
}

sub files {
    my ($self, $file) = @_;

    $self->_set_have_r_package_not_arch_all(1)
      if $file->name =~ m,^usr/lib/R/.*/DESCRIPTION,
      && !$file->is_dir
      && $self->package =~ /^r-(?:cran|bioc|other)-/
      && $file->file_contents =~ m/NeedsCompilation: no/m
      && $self->architecture ne 'all';

    return;
}

sub breakdown {
    my ($self) = @_;

    $self->tag('r-package-not-arch-all')
      if $self->have_r_package_not_arch_all;

    return;
}

sub binary {
    my ($self) = @_;

    my $pkg = $self->package;
    my $info = $self->info;

    my $unsplit = $info->unfolded_field('architecture');

    return
      unless defined $unsplit;

    my @list = split(m/ /o, $unsplit);

    return
      unless @list;

    for my $architecture (@list) {
        $self->tag('arch-wildcard-in-binary-package', $architecture)
          if is_arch_wildcard($architecture);
    }

    $self->tag('too-many-architectures') if @list > 1;

    my $architecture = $list[0];

    return
      if $architecture eq 'all';

    $self->tag('aspell-package-not-arch-all')
      if $pkg =~ /^aspell-[a-z]{2}(?:-.*)?$/;

    $self->tag('documentation-package-not-architecture-independent')
      if $pkg =~ /-docs?$/;

    return;
}

sub always {
    my ($self) = @_;

    my $type = $self->type;
    my $info = $self->info;

    my $architecture = $info->unfolded_field('architecture');

    unless (defined $architecture) {
        $self->tag('no-architecture-field');
        return;
    }

    my @list = split(m/ /o, $architecture);

    for my $arch (@list) {

        $self->tag('unknown-architecture', $arch)
          unless is_arch_or_wildcard($arch);
    }

    if (@list > 1) {    # Check for magic architecture combinations.

        my %archmap;
        my $magic = 0;

        $archmap{$_}++ for (@list);

        $magic++
          if $type ne 'source' && $archmap{'all'};

        if ($archmap{'any'}) {

            delete $archmap{'any'};

            # Allow 'all' to be present in source packages as well
            # (#626775)
            delete $archmap{'all'}
              if $type eq 'source';

            $magic++
              if %archmap;
        }

        $self->tag('magic-arch-in-arch-list') if $magic;
    }

    # Used for later tests.
    my $arch_indep = 0;
    $arch_indep = 1
      if @list == 1 && $list[0] eq 'all';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
