# files/names -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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
    my ($self, $file) = @_;

    # unusual characters
    $self->hint('file-name-ends-in-whitespace', $file->name)
      if $file->name =~ /\s+\z/;

    $self->hint('star-file', $file->name)
      if $file->name =~ m{/\*\z};

    $self->hint('hyphen-file', $file->name)
      if $file->name =~ m{/-\z};

    $self->hint('file-name-contains-wildcard-character', $file->name)
      if $file->name =~ m{[*?]};

    $self->hint('package-contains-compiled-glib-schema', $file->name)
      if $file->name
      =~ m{^ usr/share/ glib-[^/]+ /schemas/ gschemas[.]compiled $}x;

    $self->hint('package-contains-file-in-etc-skel', $file->name)
      if $file->dirname =~ m{^etc/skel/}
      && $file->basename
      !~ m{^ [.]bashrc | [.]bash_logout | [.]m?kshrc | [.]profile $}x;

    $self->hint('package-contains-file-in-usr-share-hal', $file->name)
      if $file->dirname =~ m{^usr/share/hal/};

    $self->hint('package-contains-icon-cache-in-generic-dir', $file->name)
      if $file->name eq 'usr/share/icons/hicolor/icon-theme.cache';

    $self->hint('package-contains-python-dot-directory', $file->name)
      if $file->dirname
      =~ m{^ usr/lib/python[^/]+ / (?:dist|site)-packages / }x
      && $file->name =~ m{ / [.][^/]+ / }x;

    $self->hint('package-contains-python-coverage-file', $file->name)
      if $file->basename eq '.coverage';

    $self->hint('package-contains-python-doctree-file', $file->name)
      if $file->basename =~ m{ [.]doctree (?:[.]gz)? $}x;

    $self->hint('package-contains-python-header-in-incorrect-directory',
        $file->name)
      if $file->dirname =~ m{^ usr/include/python3[.][01234567]/ }x
      && $file->name =~ m{ [.]h $}x;

    $self->hint('package-contains-python-hypothesis-example', $file->name)
      if $file->dirname =~ m{ /[.]hypothesis/examples/ }x;

    $self->hint('package-contains-python-tests-in-global-namespace',
        $file->name)
      if $file->name
      =~ m{^ usr/lib/python[^\/]+ / (?:dist|site)-packages / test_.+[.]py $}x;

    $self->hint('package-contains-sass-cache-directory', $file->name)
      if $file->name =~ m{ / [.]sass-cache / }x;

    $self->hint('package-contains-eslint-config-file', $file->name)
      if $file->basename =~ m{^ [.]eslintrc }x;

    $self->hint('package-contains-npm-ignore-file', $file->name)
      if $file->basename eq '.npmignore';

    if (exists($PATH_DIRECTORIES{$file->dirname})) {

        $self->hint('file-name-in-PATH-is-not-ASCII', $file->name)
          if $file->basename !~ m{\A [[:ascii:]]++ \Z}xsm;

        $self->hint('zero-byte-executable-in-path', $file->name)
          if $file->is_regular_file
          and $file->is_executable
          and $file->size == 0;

    } elsif (!valid_utf8($file->name)) {
        $self->hint('shipped-file-without-utf8-name', $file->name);
    }

    return;
}

sub source {
    my ($self) = @_;

    unless ($self->processable->native) {

        my @orig_non_utf8 = grep { !valid_utf8($_->name) }
          @{$self->processable->orig->sorted_list};

        $self->hint('upstream-file-without-utf8-name', $_->name)
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
