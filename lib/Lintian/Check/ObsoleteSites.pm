# obsolete-sites -- lintian check script -*- perl -*-

# Copyright © 2015 Axel Beckert <abe@debian.org>
# Copyright © 2017-2018 Chris Lamb <lamby@debian.org>
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

use Moo;
use namespace::clean;

with 'Lintian::Check';

my @interesting_files = qw(
  control
  copyright
  watch
  upstream
  upstream-metadata.yaml
);

sub source {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $type = $self->processable->type;
    my $processable = $self->processable;

    my $debian_dir = $processable->patched->resolve_path('debian/');
    return unless $debian_dir;
    foreach my $file (@interesting_files) {
        my $dfile = $debian_dir->child($file);
        $self->search_for_obsolete_sites($dfile, "debian/$file");
    }

    my $upstream_dir = $processable->patched->resolve_path('debian/upstream');
    return unless $upstream_dir;

    my $dfile = $upstream_dir->child('metadata');
    $self->search_for_obsolete_sites($dfile, 'debian/upstream/metadata');

    return;
}

sub search_for_obsolete_sites {
    my ($self, $dfile, $file) = @_;

    my $OBSOLETE_SITES
      = $self->profile->load_data('obsolete-sites/obsolete-sites');

    if (defined($dfile) and $dfile->is_regular_file and $dfile->is_open_ok) {

        my $dcontents = $dfile->bytes;

        # Strip comments
        $dcontents =~ s/^\s*#.*$//gm;

        foreach my $site ($OBSOLETE_SITES->all) {
            if ($dcontents
                =~ m{(\w+://(?:[\w.]*\.)?\Q$site\E[/:][^\s\"<>\$]*)}i) {
                $self->hint('obsolete-url-in-packaging', $file, $1);
            }
        }

        $self->hint('obsolete-url-in-packaging', $file, $1)
          if $dcontents =~m{(ftp://(?:ftp|security)\.debian\.org)}i;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
