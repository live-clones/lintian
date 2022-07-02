# desktop/gnome/gir -- lintian check script for GObject-Introspection -*- perl -*-
#
# Copyright (C) 2012 Arno Toell
# Copyright (C) 2014 Collabora Ltd.
# Copyright (C) 2016 Simon McVittie
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

package Lintian::Check::Desktop::Gnome::Gir;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $DOLLAR => q{$};

const my $NONE => q{NONE};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $debian_control = $self->processable->debian_control;

    for my $installable ($debian_control->installables) {

        $self->pointed_hint('typelib-missing-gir-depends',
            $debian_control->item->pointer, $installable)
          if $installable =~ m/^gir1\.2-/
          && !$self->processable->binary_relation($installable, 'strong')
          ->satisfies($DOLLAR . '{gir:Depends}');
    }

    return;
}

sub installable {
    my ($self) = @_;

    my $DEB_HOST_MULTIARCH= $self->data->architectures->deb_host_multiarch;
    my $triplet = $DEB_HOST_MULTIARCH->{$self->processable->architecture};

    # Slightly contrived, but it might be Architecture: all, in which
    # case this is the best we can do
    $triplet = $DOLLAR . '{DEB_HOST_MULTIARCH}'
      unless defined $triplet;

    my $xml_dir
      = $self->processable->installed->resolve_path('usr/share/gir-1.0/');

    my @girs;
    @girs = grep { $_->name =~ m{ [.]gir $}x } $xml_dir->children
      if defined $xml_dir;

    my @type_libs;

    my $old_dir
      = $self->processable->installed->resolve_path(
        'usr/lib/girepository-1.0/');

    if (defined $old_dir) {

        $self->pointed_hint('typelib-not-in-multiarch-directory',
            $_->pointer,"usr/lib/$triplet/girepository-1.0")
          for $old_dir->children;

        push(@type_libs, $old_dir->children);
    }

    my $multiarch_dir= $self->processable->installed->resolve_path(
        "usr/lib/$triplet/girepository-1.0");
    push(@type_libs, $multiarch_dir->children)
      if defined $multiarch_dir;

    my $section = $self->processable->fields->value('Section');
    if ($section ne 'libdevel' && $section ne 'oldlibs') {

        $self->pointed_hint('gir-section-not-libdevel', $_->pointer,
            $section || $NONE)
          for @girs;
    }

    if ($section ne 'introspection' && $section ne 'oldlibs') {

        $self->pointed_hint('typelib-section-not-introspection',
            $_->pointer, $section || $NONE)
          for @type_libs;
    }

    if ($self->processable->architecture eq 'all') {

        $self->pointed_hint('gir-in-arch-all-package', $_->pointer)for @girs;

        $self->pointed_hint('typelib-in-arch-all-package', $_->pointer)
          for @type_libs;
    }

  GIR: for my $gir (@girs) {

        my $expected = 'gir1.2-' . lc($gir->basename);
        $expected =~ s/\.gir$//;
        $expected =~ tr/_/-/;

        for my $installable ($self->group->get_installables) {
            next
              unless $installable->name =~ m/^gir1\.2-/;

            my $name = $installable->name;
            my $version = $installable->fields->value('Version');

            next GIR
              if $installable->relation('Provides')->satisfies($expected)
              && $self->processable->relation('strong')
              ->satisfies("$name (= $version)");
        }

        my $our_version = $self->processable->fields->value('Version');

        $self->pointed_hint('gir-missing-typelib-dependency',
            $gir->pointer, $expected)
          unless $self->processable->relation('strong')
          ->satisfies("$expected (= $our_version)");
    }

    for my $type_lib (@type_libs) {

        my $expected = 'gir1.2-' . lc($type_lib->basename);
        $expected =~ s/\.typelib$//;
        $expected =~ tr/_/-/;

        $self->pointed_hint('typelib-package-name-does-not-match',
            $type_lib->pointer, $expected)
          if $self->processable->name ne $expected
          && !$self->processable->relation('Provides')->satisfies($expected);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
