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

package Lintian::Check::Fields::Architecture;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

has installable_architecture => (is => 'rw', default => $EMPTY);

sub installable {
    my ($self) = @_;

    my @installable_architectures
      = $self->processable->fields->trimmed_list('Architecture');
    return
      unless @installable_architectures;

    for my $installable_architecture (@installable_architectures) {
        $self->hint('arch-wildcard-in-binary-package',
            $installable_architecture)
          if $self->profile->architectures->is_wildcard(
            $installable_architecture);
    }

    $self->hint('too-many-architectures', (sort @installable_architectures))
      if @installable_architectures > 1;

    my $installable_architecture = $installable_architectures[0];

    $self->hint('aspell-package-not-arch-all')
      if $self->processable->name =~ /^aspell-[a-z]{2}(?:-.*)?$/
      && $installable_architecture ne 'all';

    $self->hint('documentation-package-not-architecture-independent')
      if $self->processable->name =~ /-docs?$/
      && $installable_architecture ne 'all';

    return;
}

sub always {
    my ($self) = @_;

    my @installable_architectures
      = $self->processable->fields->trimmed_list('Architecture');
    for my $installable_architecture (@installable_architectures) {

        $self->hint('unknown-architecture', $installable_architecture)
          unless $self->profile->architectures->is_release_architecture(
            $installable_architecture)
          || $self->profile->architectures->is_wildcard(
            $installable_architecture)
          || $installable_architecture eq 'all'
          || (
            $installable_architecture eq 'source'
            && (   $self->processable->type eq 'changes'
                || $self->processable->type eq 'buildinfo'));
    }

    # check for magic installable architecture combinations
    if (@installable_architectures > 1) {

        my $magic_error = 0;

        if (any { $_ eq 'all' } @installable_architectures) {
            $magic_error++
              unless any { $self->processable->type eq $_ }
            qw(source changes buildinfo);
        }

        my $anylc = List::Compare->new(\@installable_architectures, ['any']);
        if ($anylc->get_intersection) {

            my @errorset = $anylc->get_Lonly;

            # Allow 'all' to be present in source packages as well
            # (#626775)
            @errorset = grep { $_ ne 'all' } @errorset
              if any { $self->processable->type eq $_ }
            qw(source changes buildinfo);

            $magic_error++
              if @errorset;
        }

        $self->hint('magic-arch-in-arch-list') if $magic_error;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
