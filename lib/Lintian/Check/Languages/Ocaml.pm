# languages/ocaml -- lintian check script -*- perl -*-
#
# Copyright © 2009 Stéphane Glondu
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

package Lintian::Check::Languages::Ocaml;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(first_value);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SLASH => q{/};

has provided_o => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %provided_o;

        for my $item (@{$self->processable->installed->sorted_list}) {

            for my $count (keys %{$item->ar_info}) {

                my $member = $item->ar_info->{$count}{name};
                next
                  unless length $member;

                # dirname ends in a slash
                my $virtual_path = $item->dirname . $member;

                # Note: a .o may be legitimately in several different .a
                $provided_o{$virtual_path} = $item->name;
            }
        }

        return \%provided_o;
    });

has is_dev_package => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        # is it a development package?
        return 1
          if (
            $self->processable->name =~ m{
           (?: -dev
              |\A camlp[45](?:-extra)?
              |\A ocaml  (?:
                     -nox
                    |-interp
                    |-compiler-libs
                  )?
           )\Z}xsm
          );

        return 0;
    });

has development_files => (is => 'rw', default => sub { [] });

has has_meta => (is => 'rw', default => 0);

sub visit_installed_files {
    my ($self, $file) = @_;

    my $no_extension = $file->name;
    $no_extension =~ s{ [.] [^.]+ $}{}x;

    # For each .cmxa file, there must be a matching .a file (#528367)
    $self->hint('ocaml-dangling-cmxa', $file)
      if $file->name =~ m{ [.]cmxa $}x
      && !$self->processable->installed->lookup($no_extension . '.a');

    # For each .cmxs file, there must be a matching .cma or .cmo file
    # (at least, in library packages)
    $self->hint('ocaml-dangling-cmxs', $file)
      if $file->name =~ m{ [.]cmxs $}x
      && !$self->processable->installed->lookup($no_extension . '.cma')
      && !$self->processable->installed->lookup($no_extension . '.cmo')
      && $self->processable->name =~ /^lib/;

    # The .cmx counterpart: for each .cmx file, there must be a
    # matching .o file, which can be there by itself, or embedded in a
    # .a file in the same directory
    $self->hint('ocaml-dangling-cmx', $file)
      if $file->name =~ m{ [.]cmx $}x
      && !$self->processable->installed->lookup($no_extension . '.o')
      && !exists $self->provided_o->{$no_extension . '.o'};

    # $somename.cmi should be shipped with $somename.mli or $somename.ml
    $self->hint('ocaml-dangling-cmi', $file)
      if $file->name =~ m{ [.]cmi $}x
      && !$self->processable->installed->lookup($no_extension . '.mli')
      && !$self->processable->installed->lookup($no_extension . '.ml')
      && $self->is_dev_package;

    # .cma, .cmo and .cmxs are excluded because they can be plugins
    push(@{$self->development_files}, $file->name)
      if $file->name =~ m{ [.] cm (?: i | xa? ) $}x;

    # $somename.cmo should usually not be shipped with $somename.cma
    $self->hint('ocaml-stray-cmo', $file)
      if $file->name =~ m{ [.]cma $}x
      && $self->processable->installed->lookup($no_extension . '.cmo');

    # does the package provide a META file?
    $self->has_meta(1)
      if $file =~ m{^ usr/lib/ocaml/ (?: .+ / )? META ([.] .* )? $}x;

    return;
}

sub installable {
    my ($self) = @_;

    my $depends = $self->processable->relation('all');

    # If there is a META file, ocaml-findlib should at least be suggested.
    $self->hint('ocaml-meta-without-suggesting-findlib')
      if $self->has_meta
      && $self->is_dev_package
      && !$depends->satisfies('ocaml-findlib');

    if ($self->is_dev_package) {

        # development files outside /usr/lib/ocaml (.cmi, .cmx, .cmxa)
        my @misplaced_files
          = grep { !m{^ usr/lib/ocaml/ }x } @{$self->development_files};

        my $count = scalar @misplaced_files;
        my $plural = ($count == 1) ? $EMPTY : 's';

        my $prefix = longest_common_prefix(@misplaced_files);

        # strip trailing slash
        $prefix =~ s{ / $}{}x
          unless $prefix eq $SLASH;

        $self->hint(
            'ocaml-dev-file-not-in-usr-lib-ocaml',
            "$count file$plural in $prefix"
        );
    }

    # non-dev packages should not ship .cmi, .cmx or .cmxa files
    if (!$self->is_dev_package
        && @{$self->development_files}) {

        my $count = scalar @{$self->development_files};
        my $plural = ($count == 1) ? $EMPTY : 's';

        my $prefix = longest_common_prefix(@{$self->development_files});

        # strip trailing slash
        $prefix =~ s{ / $}{}x
          unless $prefix eq $SLASH;

        $self->hint(
            'ocaml-dev-file-in-nondev-package',
            "$count file$plural in $prefix"
        );
    }

    return;
}

sub longest_common_prefix {
    my (@paths) = @_;

    my %prefixes;

    for my $path (@paths) {

        my $truncated = $path;

        # first operation drops the file name
        while ($truncated =~ s{ / [^/]* $}{}x) {
            ++$prefixes{$truncated};
        }
    }

    my @by_descending_length = reverse sort keys %prefixes;

    my $common = first_value { $prefixes{$_} == @paths } @by_descending_length;

    $common ||= $SLASH;

    return $common;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
