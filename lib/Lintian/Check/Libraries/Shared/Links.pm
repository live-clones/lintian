# libraries/shared/links -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2018-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Libraries::Shared::Links;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;
use List::SomeUtils qw(any none);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $ARROW => q{->};

has development_packages => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @development_packages;

        for my $installable ($self->group->get_binary_processables) {

            push(@development_packages, $installable)
              if $installable->name =~ /-dev$/
              && $installable->relation('strong')
              ->satisfies($self->processable->name);
        }

        return \@development_packages;
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # shared library
    return
      unless @{$item->elf->{SONAME} // [] };

    my $soname = $item->elf->{SONAME}[0];

    my @ldconfig_folders = @{$self->profile->architectures->ldconfig_folders};
    return
      if none { $item->dirname eq $_ } @ldconfig_folders;

    my $versioned_name = $item->dirname . $soname;

    my $unversioned_name = $versioned_name;
    # libtool "-release" variant
    $unversioned_name =~ s/-[\d\.]+\.so$/.so/;
    # determine shlib link name (w/o version)
    $unversioned_name =~ s/\.so.+$/.so/;

    my $installed = $self->processable->installed;

    $self->hint('lacks-versioned-link-to-shared-library',
        $versioned_name, $item->name, $soname)
      unless defined $installed->lookup($versioned_name);

    $self->hint(
        'ldconfig-symlink-referencing-wrong-file',
        $versioned_name,$ARROW,$installed->lookup($versioned_name)->link,
        'instead of',$item->basename
      )
      if $versioned_name ne $item->name
      && defined $installed->lookup($versioned_name)
      && $installed->lookup($versioned_name)->is_symlink
      && $installed->lookup($versioned_name)->link ne $item->basename;

    $self->hint('ldconfig-symlink-is-not-a-symlink',
        $item->name, $versioned_name)
      if $versioned_name ne $item->name
      && defined $installed->lookup($versioned_name)
      && !$installed->lookup($versioned_name)->is_symlink;

    # shlib symlink may not exist.
    # if shlib doesn't _have_ a version, then $unversioned_name and
    # $item->name will be equal, and it's not a development link,
    # so don't complain.
    $self->hint('link-to-shared-library-in-wrong-package',
        $item->name, $unversioned_name)
      if $unversioned_name ne $item->name
      && defined $installed->lookup($unversioned_name);

    # If the shared library is in /lib, we have to look for
    # the dev symlink in /usr/lib
    $unversioned_name = "usr/$unversioned_name"
      unless $item->name =~ m{^usr/};

    my @candidates;
    push(@candidates, $unversioned_name);

    if ($self->processable->source_name =~ /^gcc-(\d+(?:.\d+)?)$/) {
        # gcc has a lot of bi-arch libs and puts the dev symlink
        # in slightly different directories (to be co-installable
        # with itself I guess).  Allegedly, clang (etc.) have to
        # handle these special cases, so it should be
        # acceptable...
        my $gcc_version = $1;
        my $link_basename = basename($unversioned_name);

        my $DEB_HOST_MULTIARCH
          = $self->profile->architectures->deb_host_multiarch;

        my @multiarch_components;

        my $madir= $DEB_HOST_MULTIARCH->{$self->processable->architecture};
        if (length $madir) {

            # For i386-*, the triplet GCC uses can be i586-* or i686-*.
            if ($madir =~ /^i386-/) {
                my $five = $madir;
                $five =~ s/^ i. /i5/msx;
                my $six = $madir;
                $six =~ s/^ i. /i6/msx;
                push(@multiarch_components, $five, $six);

            } else {
                push(@multiarch_components, $madir);
            }
        }

        # Generally we are looking for
        #  * usr/lib/gcc/MA-TRIPLET/$gcc_version/${BIARCH}$link_basename
        #
        # Where BIARCH is one of {,64/,32/,n32/,x32/,sf/,hf/}.  Note
        # the "empty string" as a possible option.
        #
        # The two-three letter name directory before the
        # basename is bi-arch names.
        my @stems;
        push(@stems,
            map { "usr/lib/gcc/$_/$gcc_version" } @multiarch_components);

        # But in the rare case we don't know the Multi-arch dir,
        # just do without it as often (but not always) works.
        push(@stems, "usr/lib/gcc/$gcc_version")
          unless @multiarch_components;

        for my $stem (@stems) {
            push(@candidates,
                map { "$stem/$_$link_basename" }
                  ($EMPTY, qw(64/ 32/ n32/ x32/ sf/ hf/)));
        }
    }

    my $found_in_dev_package = 0;

    for my $devpkg (@{$self->development_packages}) {

        $found_in_dev_package
          = any { defined $devpkg->installed->lookup($_) } @candidates;

        last
          if $found_in_dev_package;
    }

    # found -dev package; library needs a symlink
    $self->hint('lacks-unversioned-link-to-shared-library',
        $item->name, $unversioned_name)
      if ($unversioned_name eq $item->name
        || !defined $installed->lookup($unversioned_name))
      && @{$self->development_packages}
      && !$found_in_dev_package;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
