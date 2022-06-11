# libraries/shared/links -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz
# Copyright (C) 2018-2019 Chris Lamb <lamby@debian.org>
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
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Libraries::Shared::Links;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(none);

const my $ARROW => q{->};

use Moo;
use namespace::clean;

with 'Lintian::Check';

has development_packages => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @development_packages;

        for my $installable ($self->group->get_installables) {

            push(@development_packages, $installable)
              if $installable->name =~ /-dev$/
              && $installable->relation('strong')
              ->satisfies($self->processable->name);
        }

        return \@development_packages;
    }
);

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # shared library
    return
      unless @{$item->elf->{SONAME} // [] };

    my $soname = $item->elf->{SONAME}[0];

    my @ldconfig_folders = @{$self->data->architectures->ldconfig_folders};
    return
      if none { $item->dirname eq $_ } @ldconfig_folders;

    my $installed = $self->processable->installed;

    my $versioned_name = $item->dirname . $soname;
    my $versioned_item = $installed->lookup($versioned_name);

    my $unversioned_name = $versioned_name;
    # libtool "-release" variant
    $unversioned_name =~ s/-[\d\.]+\.so$/.so/;
    # determine shlib link name (w/o version)
    $unversioned_name =~ s/\.so.+$/.so/;

    $self->pointed_hint('lacks-versioned-link-to-shared-library',
        $item->pointer, $versioned_name)
      unless defined $versioned_item;

    $self->pointed_hint(
        'ldconfig-symlink-referencing-wrong-file',
        $versioned_item->pointer,'should point to',
        $versioned_item->link,'instead of',$item->basename
      )
      if $versioned_name ne $item->name
      && defined $versioned_item
      && $versioned_item->is_symlink
      && $versioned_item->link ne $item->basename;

    $self->pointed_hint(
        'ldconfig-symlink-is-not-a-symlink',
        $versioned_item->pointer,'should point to',
        $item->name
      )
      if $versioned_name ne $item->name
      && defined $versioned_item
      && !$versioned_item->is_symlink;

    # shlib symlink may not exist.
    # if shlib doesn't _have_ a version, then $unversioned_name and
    # $item->name will be equal, and it's not a development link,
    # so don't complain.
    $self->pointed_hint(
        'link-to-shared-library-in-wrong-package',
        $installed->lookup($unversioned_name)->pointer,
        $item->name
      )
      if $unversioned_name ne $item->name
      && defined $installed->lookup($unversioned_name);

    # If the shared library is in /lib, we have to look for
    # the dev symlink in /usr/lib
    $unversioned_name = "usr/$unversioned_name"
      unless $item->name =~ m{^usr/};

    my @dev_links;
    for my $dev_installable (@{$self->development_packages}) {
        for my $dev_item (@{$dev_installable->installed->sorted_list}) {

            next
              unless $dev_item->is_symlink;

            next
              unless $dev_item->name =~ m{^ usr/lib/ }x;

            # try absolute first
            my $resolved = $installed->resolve_path($dev_item->link);

            # otherwise relative
            $resolved
              = $installed->resolve_path($dev_item->dirname . $dev_item->link)
              unless defined $resolved;

            next
              unless defined $resolved;

            push(@dev_links, $dev_item)
              if $resolved->name eq $item->name;
        }
    }

    # found -dev package; library needs a symlink
    $self->pointed_hint('lacks-unversioned-link-to-shared-library',
        $item->pointer, "example: $unversioned_name")
      if @{$self->development_packages}
      && (none { $_->name =~ m{ [.]so $}x } @dev_links);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
