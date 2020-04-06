# desktop/gnome/gir -- lintian check script for GObject-Introspection -*- perl -*-
#
# Copyright © 2012 Arno Töll
# Copyright © 2014 Collabora Ltd.
# Copyright © 2016 Simon McVittie
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

package Lintian::desktop::gnome::gir;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $MA_DIRS = Lintian::Data->new('common/multiarch-dirs', qr/\s++/);

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    foreach my $bin ($processable->binaries) {
        if ($bin =~ m/^gir1\.2-/) {
            if (
                not $processable->binary_relation($bin, 'strong')
                ->implies('${gir:Depends}')) {
                $self->tag(('typelib-missing-gir-depends', $bin));
            }
        }
    }

    return;
}

sub installable {
    my ($self) = @_;

    my $pkg = $self->package;
    my $processable = $self->processable;
    my $group = $self->group;

    my @girs;
    my @typelibs;
    my $section = $processable->field('section', 'NONE');
    my $madir = $MA_DIRS->value($processable->architecture);
    # Slightly contrived, but it might be Architecture: all, in which
    # case this is the best we can do
    $madir = '${DEB_HOST_MULTIARCH}' unless defined $madir;

    if (my $xmldir
        = $processable->installed->resolve_path('usr/share/gir-1.0/')) {
        foreach my $child ($xmldir->children) {
            next unless $child =~ m/\.gir$/;
            push @girs, $child;
        }
    }

    if (my $dir
        = $processable->installed->resolve_path('usr/lib/girepository-1.0/')) {
        push @typelibs, $dir->children;
        foreach my $typelib ($dir->children) {
            $self->tag((
                'typelib-not-in-multiarch-directory',$typelib,
                "usr/lib/$madir/girepository-1.0"
            ));
        }
    }

    if (
        my $dir= $processable->installed->resolve_path(
            "usr/lib/$madir/girepository-1.0")
    ){
        push @typelibs, $dir->children;
    }

    if ($section ne 'libdevel' && $section ne 'oldlibs') {
        foreach my $gir (@girs) {
            $self->tag(('gir-section-not-libdevel', $gir, $section));
        }
    }

    if ($section ne 'introspection' && $section ne 'oldlibs') {
        foreach my $typelib (@typelibs) {
            $self->tag(
                ('typelib-section-not-introspection', $typelib, $section));
        }
    }

    if ($processable->architecture eq 'all') {
        foreach my $gir (@girs) {
            $self->tag(('gir-in-arch-all-package', $gir));
        }
        foreach my $typelib (@typelibs) {
            $self->tag(('typelib-in-arch-all-package', $typelib));
        }
    }

  GIR: foreach my $gir (@girs) {
        my $expected = 'gir1.2-' . lc($gir->basename);
        $expected =~ s/\.gir$//;
        $expected =~ tr/_/-/;
        my $version = $processable->field('version');

        foreach my $bin ($group->get_binary_processables) {
            next unless $bin->name =~ m/^gir1\.2-/;
            my $other = $bin->name.' (= '.$bin->field('version').')';
            if (    $bin->relation('provides')->implies($expected)
                and $processable->relation('strong')->implies($other)) {
                next GIR;
            }
        }

        if (
            not $processable->relation('strong')
            ->implies("$expected (= $version)")) {
            $self->tag(('gir-missing-typelib-dependency', $gir, $expected));
        }
    }

    foreach my $typelib (@typelibs) {
        my $expected = 'gir1.2-' . lc($typelib->basename);
        $expected =~ s/\.typelib$//;
        $expected =~ tr/_/-/;
        if ($pkg ne $expected
            and not $processable->relation('provides')->implies($expected)) {
            $self->tag(
                ('typelib-package-name-does-not-match', $typelib, $expected));
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
