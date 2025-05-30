# binaries/hardening -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2012 Kees Cook
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2021 Felix Lechner
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Binaries::Hardening;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has HARDENED_FUNCTIONS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->data->load('binaries/hardened-functions');
    }
);

has recommended_hardening_features => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %recommended_hardening_features;

        my $hardening_buildflags = $self->data->hardening_buildflags;
        my $architecture = $self->processable->fields->value('Architecture');

        %recommended_hardening_features
          = map { $_ => 1 }
          @{$hardening_buildflags->recommended_features->{$architecture}}
          if $architecture ne 'all';

        return \%recommended_hardening_features;
    }
);

# TODO the logic is duplicated in lib/Lintian/Check/Binaries/Static.pm
has built_with_golang => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        # Check source package name starts with "golang-"
        if ($self->processable->source_name =~ m/^golang-/) {
            return 1;
        }

        # Check package section is golang
        if ($self->processable->fields->value('Section') eq 'golang') {
            return 1;
        }

        # Check binary package was built using golang
        if (
            $self->processable->fields->value('Built-Using')
            =~ m/golang-\d\.\d+/
            ||$self->processable->fields->value(
                'Static-Built-Using')=~ m/golang-\d\.\d+/
        ) {
            return 1;
        }

        # Check binary package name starts with "golang-"
        if ($self->processable->name =~ m/^golang-/) {
            return 1;
        }

        # Check source package build-depends contains a golang compiler
        if (defined($self->group->source)) {
            return $self->group->source->relation('Build-Depends-All')
              ->satisfies('golang-go | golang-any');
        }

        return 0;
    }
);

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

    $self->pointed_hint('hardening-no-fortify-functions', $item->pointer)
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

        $self->pointed_hint('hardening-no-fortify-functions',
            $item->pointer, $member_name)
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
      if $item->file_type !~ m{^ [^,]* \b ELF \b }x
      || $item->file_type !~ m{ \b executable | shared [ ] object \b }x;

    # dynamically linked?
    return
      unless exists $item->elf->{NEEDED};

    $self->pointed_hint('hardening-no-relro', $item->pointer)
      if $self->recommended_hardening_features->{relro}
      && !$self->built_with_golang
      && !$item->elf->{PH}{RELRO};

    $self->pointed_hint('hardening-no-bindnow', $item->pointer)
      if $self->recommended_hardening_features->{bindnow}
      && !$self->built_with_golang
      && !exists $item->elf->{FLAGS_1}{NOW};

    $self->pointed_hint('hardening-no-pie', $item->pointer)
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
