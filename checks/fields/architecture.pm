# fields/architecture -- lintian check script (rewrite) -*- perl -*-
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

package Lintian::fields::architecture;

use v5.20;
use warnings;
use utf8;
use autodie;

use Const::Fast;
use List::Compare;
use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };

has architecture => (is => 'rw', default => $EMPTY);
has have_r_package_not_arch_all => (is => 'rw', default => 0);

sub setup_installed_files {
    my ($self) = @_;

    my $unsplit = $self->processable->fields->unfolded_value('Architecture');

    my @architectures = split($SPACE, $unsplit);

    return
      unless @architectures;

    $self->architecture($architectures[0]);

    return;
}

sub visit_installed_files {
    my ($self, $file) = @_;

    $self->have_r_package_not_arch_all(1)
      if $file->name =~ m{^usr/lib/R/.*/DESCRIPTION}
      && !$file->is_dir
      && $self->processable->name =~ /^r-(?:cran|bioc|other)-/
      && $file->bytes =~ m/NeedsCompilation: no/m
      && $self->architecture ne 'all';

    return;
}

sub breakdown_installed_files {
    my ($self) = @_;

    $self->hint('r-package-not-arch-all')
      if $self->have_r_package_not_arch_all;

    return;
}

sub installable {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $processable = $self->processable;

    my $unsplit = $processable->fields->unfolded_value('Architecture');

    my @architectures = split($SPACE, $unsplit);

    return
      unless @architectures;

    for my $architecture (@architectures) {
        $self->hint('arch-wildcard-in-binary-package', $architecture)
          if $self->profile->architectures->is_wildcard($architecture);
    }

    $self->hint('too-many-architectures') if @architectures > 1;

    my $architecture = $architectures[0];

    return
      if $architecture eq 'all';

    $self->hint('aspell-package-not-arch-all')
      if $pkg =~ /^aspell-[a-z]{2}(?:-.*)?$/;

    $self->hint('documentation-package-not-architecture-independent')
      if $pkg =~ /-docs?$/;

    return;
}

sub always {
    my ($self) = @_;

    my $type = $self->processable->type;
    my $processable = $self->processable;

    my $unsplit = $processable->fields->unfolded_value('Architecture');
    my @architectures = split($SPACE, $unsplit);

    for my $architecture (@architectures) {

        $self->hint('unknown-architecture', $architecture)
          unless $self->profile->architectures->is_arch($architecture)
          || $self->profile->architectures->is_wildcard($architecture)
          || $architecture eq 'all'
          || ($architecture eq 'source'
            && ($type eq 'changes' || $type eq 'buildinfo'));
    }

    # check for magic architecture combinations
    if (@architectures > 1) {

        my $magic_error = 0;

        if (any { $_ eq 'all' } @architectures) {
            $magic_error++
              unless any { $type eq $_ } qw(source changes buildinfo);
        }

        my $anylc = List::Compare->new(\@architectures, ['any']);
        if ($anylc->get_intersection) {

            my @errorset = $anylc->get_Lonly;

            # Allow 'all' to be present in source packages as well
            # (#626775)
            @errorset = grep { $_ ne 'all' } @errorset
              if any { $type eq $_ } qw(source changes buildinfo);

            $magic_error++
              if @errorset;
        }

        $self->hint('magic-arch-in-arch-list') if $magic_error;
    }

    # Used for later tests.
    my $arch_indep = 0;
    $arch_indep = 1
      if @architectures == 1 && $architectures[0] eq 'all';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
