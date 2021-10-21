# files/empty-package -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2019 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Files::EmptyPackage;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# Common files stored in /usr/share/doc/$pkg that aren't sufficient to
# consider the package non-empty.
has STANDARD_FILES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('files/standard-files');
    });

has is_empty => (is => 'rw', default => 1);
has is_dummy => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        # check if package is empty
        return 1
          if $self->processable->is_transitional
          || $self->processable->is_meta_package;

        return 0;
    });

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      unless $self->is_empty;

    return
      if $self->is_dummy;

    # ignore directories
    return
      if $file->is_dir;

    my $pkg = $self->processable->name;
    my $ppkg = quotemeta($self->processable->name);

    # skip if file is outside /usr/share/doc/$pkg directory
    if ($file->name !~ m{^usr/share/doc/\Q$pkg\E}) {

        # - except if it is a lintian override.
        return
          if $file->name =~ m{\A
                             # Except for:
                             usr/share/ (?:
                                 # lintian overrides
                                 lintian/overrides/$ppkg(?:\.gz)?
                                 # reportbug scripts/utilities
                             | bug/$ppkg(?:/(?:control|presubj|script))?
                             )\Z}xsm;

        $self->is_empty(0);

        return;
    }

    # skip if /usr/share/doc/$pkg has files in a subdirectory
    if ($file->name =~ m{^usr/share/doc/\Q$pkg\E/[^/]+/}) {

        $self->is_empty(0);

        return;
    }

    # skip /usr/share/doc/$pkg symlinks.
    return
      if $file->name eq "usr/share/doc/$pkg";

    # For files directly in /usr/share/doc/$pkg, if the
    # file isn't one of the uninteresting ones, the
    # package isn't empty.
    return
      if $self->STANDARD_FILES->recognizes($file->basename);

    # ignore all READMEs
    return
      if $file->basename =~ m/^README(?:\..*)?$/i;

    my $pkg_arch = $self->processable->architecture;
    unless ($pkg_arch eq 'all') {

        # binNMU changelog (debhelper)
        return
          if $file->basename eq "changelog.Debian.${pkg_arch}.gz";
    }

    # buildinfo file (dh-buildinfo)
    return
      if $file->basename eq "buildinfo_${pkg_arch}.gz";

    $self->is_empty(0);

    return;
}

sub installable {
    my ($self) = @_;

    return
      if $self->is_dummy;

    if ($self->is_empty) {

        $self->hint('empty-binary-package')
          if $self->processable->type eq 'binary';

        $self->hint('empty-udeb-package')
          if $self->processable->type eq 'udeb';
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
