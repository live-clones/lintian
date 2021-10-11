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
use File::Basename;
use Path::Tiny;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

# The maximum number of *.cmi files to show individually.
const my $MAX_CMI => 3;

has provided_o => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %provided_o;

        for my $item (@{$self->processable->installed->sorted_list}) {

            my $ar_info = $item->ar_info;
            next
              unless scalar keys %{$ar_info};

            # ends in a slash
            my $dirname = $item->dirname;

            for my $count (keys %{$ar_info}) {

                my $member = $ar_info->{$count}{name};
                # Note: a .o may be legitimately in several different .a
                $provided_o{"$dirname$member"} = $item->name
                  if length $member;
            }
        }

        return \%provided_o;
    });

has is_lib_package => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        # is it a library package?
        return 1
          if $self->processable->name =~ /^lib/;

        return 0;
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

# for libraries outside /usr/lib/ocaml
has outside_number => (is => 'rw', default => 0);
has outside_prefix => (is => 'rw');

# dangling .cmi files (we show only $MAX_CMI of them)
has cmi_number => (is => 'rw', default => 0);

# dev files in nondev package
has dev_number => (is => 'rw', default => 0);
has dev_prefix => (is => 'rw');

# does the package provide a META file?
has has_meta => (is => 'rw', default => 0);

sub visit_installed_files {
    my ($self, $file) = @_;

    # For each .cmxa file, there must be a matching .a file (#528367)
    $_ = $file;
    if (s/\.cmxa$/.a/ && !$self->processable->installed->lookup($_)) {
        $self->hint('ocaml-dangling-cmxa', $file);
    }

    # For each .cmxs file, there must be a matching .cma or .cmo file
    # (at least, in library packages)
    if ($self->is_lib_package) {
        $_ = $file;
        if (   s/\.cmxs$/.cm/
            && !$self->processable->installed->lookup("${_}a")
            && !$self->processable->installed->lookup("${_}o")) {
            $self->hint('ocaml-dangling-cmxs', $file);
        }
    }

    # The .cmx counterpart: for each .cmx file, there must be a
    # matching .o file, which can be there by itself, or embedded in a
    # .a file in the same directory
    $_ = $file;
    if (   s/\.cmx$/.o/
        && !$self->processable->installed->lookup($_)
        && !(exists $self->provided_o->{$_})) {
        $self->hint('ocaml-dangling-cmx', $file);
    }

    # $somename.cmi should be shipped with $somename.mli or $somename.ml
    $_ = $file;
    if (   $self->is_dev_package
        && s/\.cmi$/.ml/
        && !$self->processable->installed->lookup("${_}i")
        && !$self->processable->installed->lookup($_)) {
        $self->cmi_number($self->cmi_number + 1);
        if ($self->cmi_number <= $MAX_CMI) {
            $self->hint('ocaml-dangling-cmi', $file);
        }
    }

    # non-dev packages should not ship .cmi, .cmx or .cmxa files
    if ($file =~ m/\.cm(i|xa?)$/) {
        $self->dev_number($self->dev_number + 1);
        if (defined $self->dev_prefix) {
            my $dev_prefix = $self->dev_prefix;
            chop $dev_prefix while ($file !~ m{^$dev_prefix});
            $self->dev_prefix($dev_prefix);
        } else {
            $self->dev_prefix($file->name);
        }
    }

    # $somename.cmo should usually not be shipped with $somename.cma
    $_ = $file;
    if (s/\.cma$/.cmo/ && $self->processable->installed->lookup($_)) {
        $self->hint('ocaml-stray-cmo', $file);
    }

    # development files outside /usr/lib/ocaml (.cmi, .cmx, .cmxa)
    # .cma, .cmo and .cmxs are excluded because they can be plugins
    if ($file =~ m/\.cm(i|xa?)$/ && $file !~ m{^usr/lib/ocaml/}) {
        $self->outside_number($self->outside_number + 1);
        if (defined $self->outside_prefix) {
            my $outside_prefix = $self->outside_prefix;
            chop $outside_prefix while ($file !~ m{^$outside_prefix});
            $self->outside_prefix($outside_prefix);
        } else {
            $self->outside_prefix($file->name);
        }
    }

    # If there is a META file, ocaml-findlib should be at least suggested.
    $self->has_meta(1)
      if $file =~ m{^usr/lib/ocaml/(.+/)?META(\..*)?$};

    return;
}

sub installable {
    my ($self) = @_;

    if ($self->is_dev_package) {
        # summary about .cmi files
        if ($self->cmi_number > $MAX_CMI) {
            my $plural = ($self->cmi_number - $MAX_CMI == 1) ? $EMPTY : 's';
            $self->hint(
                'ocaml-dangling-cmi',
                ($self->cmi_number - $MAX_CMI),
                "more file$plural not shown"
            );
        }
        # summary about /usr/lib/ocaml
        if ($self->outside_number) {
            my $outside_number = $self->outside_number;
            my $outside_prefix = dirname($self->outside_prefix);
            my $plural = ($self->outside_number == 1) ? $EMPTY : 's';
            $self->hint('ocaml-dev-file-not-in-usr-lib-ocaml',
                "$outside_number file$plural in $outside_prefix");
        }
        if ($self->has_meta) {
            my $depends = $self->processable->relation('all');
            $self->hint('ocaml-meta-without-suggesting-findlib')
              unless $depends->satisfies('ocaml-findlib');
        }
    } else {
        # summary about dev files
        if ($self->dev_number > 0) {
            my $dev_number = $self->dev_number;
            my $dev_prefix = dirname($self->dev_prefix);
            my $plural = ($self->dev_number == 1) ? $EMPTY : 's';
            $self->hint(
                'ocaml-dev-file-in-nondev-package',
                "$dev_number file$plural in $dev_prefix"
            );
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
