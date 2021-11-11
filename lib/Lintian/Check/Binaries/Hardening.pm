# binaries/hardening -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2012 Kees Cook
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Binaries::Hardening;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $COLON => q{:};
const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

has HARDENED_FUNCTIONS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/hardened-functions');
    });

has recommended_hardening_features => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %recommended_hardening_features;

        my $hardening_buildflags = $self->profile->hardening_buildflags;
        my $architecture = $self->processable->fields->value('Architecture');

        %recommended_hardening_features
          = map { $_ => 1 }
          @{$hardening_buildflags->recommended_features->{$architecture}}
          if $architecture ne 'all';

        return \%recommended_hardening_features;
    });

has built_with_golang => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $built_with_golang = $self->processable->name =~ m/^golang-/;

        my $source = $self->group->source;

        $built_with_golang
          = $source->relation('Build-Depends-All')
          ->satisfies('golang-go | golang-any')
          if defined $source;

        return $built_with_golang;
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    my @elf_hardened;
    my @elf_unhardened;

    for my $symbol (@{$item->elf->{SYMBOLS}}) {

        next
          unless $symbol->section eq 'UND';

        if ($symbol->name =~ /^__(\S+)_chk$/) {

            my $vulnerable = $1;
            push(@elf_hardened, $vulnerable)
              if $self->HARDENED_FUNCTIONS->recognizes($vulnerable);

        } else {

            push(@elf_unhardened, $symbol->name)
              if $self->HARDENED_FUNCTIONS->recognizes($symbol->name);
        }
    }

    $self->hint('hardening-no-fortify-functions',
        $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET)
      if @elf_unhardened
      && !@elf_hardened
      && !$self->built_with_golang
      && $self->recommended_hardening_features->{fortify};

    for my $member_name (keys %{$item->elf_by_member}) {

        my @member_hardened;
        my @member_unhardened;

        for my $symbol (@{$item->elf_by_member->{$member_name}{SYMBOLS}}) {

            next
              unless $symbol->section eq 'UND';

            if ($symbol->name =~ /^__(\S+)_chk$/) {

                my $vulnerable = $1;
                push(@member_hardened, $vulnerable)
                  if $self->HARDENED_FUNCTIONS->recognizes($vulnerable);

            } else {

                push(@member_unhardened, $symbol->name)
                  if $self->HARDENED_FUNCTIONS->recognizes($symbol->name);
            }
        }

        $self->hint('hardening-no-fortify-functions',$member_name,
                $LEFT_SQUARE_BRACKET
              . $item->name
              . $COLON
              . $member_name
              . $RIGHT_SQUARE_BRACKET)
          if @member_unhardened
          && !@member_hardened
          && !$self->built_with_golang
          && $self->recommended_hardening_features->{fortify};
    }

    return
      if $self->processable->type eq 'udeb';

    return
      unless $item->is_file;

    return
      if $item->file_info !~ m{^ [^,]* \b ELF \b }x
      || $item->file_info !~ m{ \b executable | shared [ ] object \b }x;

    # dynamically linked?
    return
      unless exists $item->elf->{NEEDED};

    $self->hint('hardening-no-relro', $item)
      if $self->recommended_hardening_features->{relro}
      && !$self->built_with_golang
      && !$item->elf->{PH}{RELRO};

    $self->hint('hardening-no-bindnow', $item)
      if $self->recommended_hardening_features->{bindnow}
      && !$self->built_with_golang
      && !exists $item->elf->{FLAGS_1}{NOW};

    $self->hint('hardening-no-pie', $item)
      if $self->recommended_hardening_features->{pie}
      && !$self->built_with_golang
      && $item->elf->{'ELF-HEADER'}{Type} =~ m{^ EXEC }x;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
