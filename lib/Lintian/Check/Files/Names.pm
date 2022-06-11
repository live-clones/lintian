# files/names -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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

package Lintian::Check::Files::Names;

use v5.20;
use warnings;
use utf8;

use List::Compare;
use Unicode::UTF8 qw(valid_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

my %PATH_DIRECTORIES = map { $_ => 1 } qw(
  bin/ sbin/ usr/bin/ usr/sbin/ usr/games/ );

sub visit_installed_files {
    my ($self, $item) = @_;

    # unusual characters
    $self->pointed_hint('file-name-ends-in-whitespace', $item->pointer)
      if $item->name =~ /\s+\z/;

    $self->pointed_hint('star-file', $item->pointer)
      if $item->name =~ m{/\*\z};

    $self->pointed_hint('hyphen-file', $item->pointer)
      if $item->name =~ m{/-\z};

    $self->pointed_hint('file-name-contains-wildcard-character',$item->pointer)
      if $item->name =~ m{[*?]};

    $self->pointed_hint('package-contains-compiled-glib-schema',$item->pointer)
      if $item->name
      =~ m{^ usr/share/ glib-[^/]+ /schemas/ gschemas[.]compiled $}x;

    $self->pointed_hint('package-contains-file-in-etc-skel', $item->pointer)
      if $item->dirname =~ m{^etc/skel/}
      && $item->basename
      !~ m{^ [.]bashrc | [.]bash_logout | [.]m?kshrc | [.]profile $}x;

    $self->pointed_hint('package-contains-file-in-usr-share-hal',
        $item->pointer)
      if $item->dirname =~ m{^usr/share/hal/};

    $self->pointed_hint('package-contains-icon-cache-in-generic-dir',
        $item->pointer)
      if $item->name eq 'usr/share/icons/hicolor/icon-theme.cache';

    $self->pointed_hint('package-contains-python-dot-directory',$item->pointer)
      if $item->dirname
      =~ m{^ usr/lib/python[^/]+ / (?:dist|site)-packages / }x
      && $item->name =~ m{ / [.][^/]+ / }x;

    $self->pointed_hint('package-contains-python-coverage-file',$item->pointer)
      if $item->basename eq '.coverage';

    $self->pointed_hint('package-contains-python-doctree-file', $item->pointer)
      if $item->basename =~ m{ [.]doctree (?:[.]gz)? $}x;

    $self->pointed_hint(
        'package-contains-python-header-in-incorrect-directory',
        $item->pointer)
      if $item->dirname =~ m{^ usr/include/python3[.][01234567]/ }x
      && $item->name =~ m{ [.]h $}x;

    $self->pointed_hint('package-contains-python-hypothesis-example',
        $item->pointer)
      if $item->dirname =~ m{ /[.]hypothesis/examples/ }x;

    $self->pointed_hint('package-contains-python-tests-in-global-namespace',
        $item->pointer)
      if $item->name
      =~ m{^ usr/lib/python[^\/]+ / (?:dist|site)-packages / test_.+[.]py $}x;

    $self->pointed_hint('package-contains-sass-cache-directory',$item->pointer)
      if $item->name =~ m{ / [.]sass-cache / }x;

    $self->pointed_hint('package-contains-eslint-config-file', $item->pointer)
      if $item->basename =~ m{^ [.]eslintrc }x;

    $self->pointed_hint('package-contains-npm-ignore-file', $item->pointer)
      if $item->basename eq '.npmignore';

    if (exists($PATH_DIRECTORIES{$item->dirname})) {

        $self->pointed_hint('file-name-in-PATH-is-not-ASCII', $item->pointer)
          if $item->basename !~ m{\A [[:ascii:]]++ \Z}xsm;

        $self->pointed_hint('zero-byte-executable-in-path', $item->pointer)
          if $item->is_regular_file
          and $item->is_executable
          and $item->size == 0;

    } elsif (!valid_utf8($item->name)) {
        $self->pointed_hint('shipped-file-without-utf8-name', $item->pointer);
    }

    return;
}

sub source {
    my ($self) = @_;

    unless ($self->processable->native) {

        my @orig_non_utf8 = grep { !valid_utf8($_->name) }
          @{$self->processable->orig->sorted_list};

        $self->pointed_hint('upstream-file-without-utf8-name', $_->pointer)
          for @orig_non_utf8;
    }

    my @patched = map { $_->name } @{$self->processable->patched->sorted_list};
    my @orig = map { $_->name } @{$self->processable->orig->sorted_list};

    my $lc= List::Compare->new(\@patched, \@orig);
    my @created = $lc->get_Lonly;

    my @non_utf8 = grep { !valid_utf8($_) } @created;

    # exclude quilt directory
    my @maintainer_fault = grep { !m{^.pc/} } @non_utf8;

    if ($self->processable->native) {
        $self->hint('native-source-file-without-utf8-name', $_)
          for @maintainer_fault;

    } else {
        $self->hint('patched-file-without-utf8-name', $_)for @maintainer_fault;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
