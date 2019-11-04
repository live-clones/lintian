# ocaml -- lintian check script -*- perl -*-
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

package Lintian::ocaml;

use strict;
use warnings;
use autodie;

use File::Basename;

use Lintian::Relation ();

use Moo;
use namespace::clean;

with 'Lintian::Check';

has provided_o => (is => 'rwp', default => sub{ {} });
has is_lib_package => (is => 'rwp', default => 0);
has is_dev_package => (is => 'rwp', default => 0);

# for libraries outside /usr/lib/ocaml
has outside_number => (is => 'rwp', default => 0);
has outside_prefix => (is => 'rwp');

# dangling .cmi files (we show only $MAX_CMI of them)
has cmi_number => (is => 'rwp', default => 0);

# dev files in nondev package
has dev_number => (is => 'rwp', default => 0);
has dev_prefix => (is => 'rwp');

# does the package provide a META file?
has has_meta => (is => 'rwp', default => 0);

# The maximum number of *.cmi files to show individually.
our $MAX_CMI = 3;

sub setup {
    my ($self) = @_;

    open(my $fd, '<', $self->info->lab_data_path('ar-info'));
    while (my $line = <$fd>) {
        chomp($line);
        if ($line =~ /^(?:\.\/)?([^:]+): (.*)$/) {
            my ($filename, $contents) = ($1, $2);
            my $dirname = dirname($filename);
            for my $entry (split m/ /o, $contents) {
                # Note: a .o may be legitimately in several different .a
                $self->provided_o->{"$dirname/$entry"} = $filename;
            }
        }
    }
    close($fd);

    # is it a library package?
    $self->_set_is_lib_package(1)
      if $self->package =~ /^lib/;

    # is it a development package?
    $self->_set_is_dev_package(1)
      if (
        $self->package =~ m/
           (?: -dev
              |\A camlp[45](?:-extra)?
              |\A ocaml  (?:
                     -nox
                    |-interp
                    |-compiler-libs
                  )?
           )\Z/xsm
      );

    return;
}

sub files {
    my ($self, $file) = @_;

    # For each .cmxa file, there must be a matching .a file (#528367)
    $_ = $file;
    if (s/\.cmxa$/.a/ && !$self->info->index($_)) {
        $self->tag('ocaml-dangling-cmxa', $file);
    }

    # For each .cmxs file, there must be a matching .cma or .cmo file
    # (at least, in library packages)
    if ($self->is_lib_package) {
        $_ = $file;
        if (   s/\.cmxs$/.cm/
            && !$self->info->index("${_}a")
            && !$self->info->index("${_}o")) {
            $self->tag('ocaml-dangling-cmxs', $file);
        }
    }

    # The .cmx counterpart: for each .cmx file, there must be a
    # matching .o file, which can be there by itself, or embedded in a
    # .a file in the same directory
    $_ = $file;
    if (   s/\.cmx$/.o/
        && !$self->info->index($_)
        && !(exists $self->provided_o->{$_})) {
        $self->tag('ocaml-dangling-cmx', $file);
    }

    # $somename.cmi should be shipped with $somename.mli or $somename.ml
    $_ = $file;
    if (   $self->is_dev_package
        && s/\.cmi$/.ml/
        && !$self->info->index("${_}i")
        && !$self->info->index($_)) {
        $self->_set_cmi_number($self->cmi_number + 1);
        if ($self->cmi_number <= $MAX_CMI) {
            $self->tag('ocaml-dangling-cmi', $file);
        }
    }

    # non-dev packages should not ship .cmi, .cmx or .cmxa files
    if ($file =~ m/\.cm(i|xa?)$/) {
        $self->_set_dev_number($self->dev_number + 1);
        if (defined $self->dev_prefix) {
            my $dev_prefix = $self->dev_prefix;
            chop $dev_prefix while ($file !~ m@^$dev_prefix@);
            $self->_set_dev_prefix($dev_prefix);
        } else {
            $self->_set_dev_prefix($file->name);
        }
    }

    # $somename.cmo should usually not be shipped with $somename.cma
    $_ = $file;
    if (s/\.cma$/.cmo/ && $self->info->index($_)) {
        $self->tag('ocaml-stray-cmo', $file);
    }

    # development files outside /usr/lib/ocaml (.cmi, .cmx, .cmxa)
    # .cma, .cmo and .cmxs are excluded because they can be plugins
    if ($file =~ m/\.cm(i|xa?)$/ && $file !~ m@^usr/lib/ocaml/@) {
        $self->_set_outside_number($self->outside_number + 1);
        if (defined $self->outside_prefix) {
            my $outside_prefix = $self->outside_prefix;
            chop $outside_prefix while ($file !~ m@^$outside_prefix@);
            $self->_set_outside_prefix($outside_prefix);
        } else {
            $self->_set_outside_prefix($file->name);
        }
    }

    # If there is a META file, ocaml-findlib should be at least suggested.
    $self->_set_has_meta(1)
      if $file =~ m@^usr/lib/ocaml/(.+/)?META(\..*)?$@;

    return;
}

sub breakdown {
    my ($self) = @_;

    if ($self->is_dev_package) {
        # summary about .cmi files
        if ($self->cmi_number > $MAX_CMI) {
            my $plural = ($self->cmi_number - $MAX_CMI == 1) ? '' : 's';
            $self->tag(
                'ocaml-dangling-cmi',
                ($self->cmi_number - $MAX_CMI),
                "more file$plural not shown"
            );
        }
        # summary about /usr/lib/ocaml
        if ($self->outside_number) {
            my $outside_number = $self->outside_number;
            my $outside_prefix = dirname($self->outside_prefix);
            my $plural = ($self->outside_number == 1) ? '' : 's';
            $self->tag('ocaml-dev-file-not-in-usr-lib-ocaml',
                "$outside_number file$plural in $outside_prefix");
        }
        if ($self->has_meta) {
            my $depends = $self->info->relation('all');
            $self->tag('ocaml-meta-without-suggesting-findlib')
              unless $depends->implies('ocaml-findlib');
        }
    } else {
        # summary about dev files
        if ($self->dev_number > 0) {
            my $dev_number = $self->dev_number;
            my $dev_prefix = dirname($self->dev_prefix);
            my $plural = ($self->dev_number == 1) ? '' : 's';
            $self->tag(
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
