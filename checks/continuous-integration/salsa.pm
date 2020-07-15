# continuous-integration/salsa -- lintian check script -*- perl -*-

# Copyright © 2020 Felix Lechner
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

package Lintian::continuous_integration::salsa;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::MoreUtils qw(any);
use YAML::XS qw(LoadFile);

use Moo;
use namespace::clean;

with 'Lintian::Check';

# ci is configured in gitlab and can be located anywere
# https://salsa.debian.org/salsa-ci-team/pipeline/-/issues/86
my @KNOWN_LOCATIONS = qw(
  debian/salsa-ci.yml
  debian/gitlab-ci.yml
  gitlab-ci.yml
  .gitlab-ci.yml
);

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless any { $item->name eq $_ } @KNOWN_LOCATIONS;

    $self->tag('specification', $item->name);

    return
      unless $item->is_open_ok;

    my $yaml = LoadFile($item->unpacked_path);
    return
      unless defined $yaml;

# tradiitonally examined via codesearch
# https://codesearch.debian.net/search?q=salsa-ci-team%2Fpipeline%2Fraw%2Fmaster%2Fsalsa-ci.yml&literal=1
    my @includes = @{$yaml->{include} // []};
    $self->tag('include', $item->name, $_) for @includes;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
