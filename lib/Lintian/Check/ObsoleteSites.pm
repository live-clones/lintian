# obsolete-sites -- lintian check script -*- perl -*-

# Copyright © 2015 Axel Beckert <abe@debian.org>
# Copyright © 2017-2018 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::ObsoleteSites;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

my @interesting_files = qw(
  control
  copyright
  watch
  upstream
  upstream/metadata
  upstream-metadata.yaml
);

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_regular_file;

    $self->search_for_obsolete_sites($item)
      if any { $item->name =~ m{^ debian/$_ $}x } @interesting_files;

    return;
}

sub search_for_obsolete_sites {
    my ($self, $item) = @_;

    return
      unless $item->is_open_ok;

    my $OBSOLETE_SITES= $self->data->load('obsolete-sites/obsolete-sites');

    my $bytes = $item->bytes;

    # strip comments
    $bytes =~ s/^ \s* [#] .* $//gmx;

    for my $site ($OBSOLETE_SITES->all) {

        if ($bytes
            =~ m{ (\w+:// (?: [\w.]* [.] )? \Q$site\E [/:] [^\s"<>\$]* ) }ix) {

            my $url = $1;
            $self->pointed_hint('obsolete-url-in-packaging', $item->pointer,
                $url);
        }
    }

    if ($bytes =~ m{ (ftp:// (?:ftp|security) [.]debian[.]org) }ix) {

        my $url = $1;
        $self->pointed_hint('obsolete-url-in-packaging', $item->pointer, $url);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
