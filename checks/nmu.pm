# nmu -- lintian check script -*- perl -*-

# Copyright © 2004 Jeroen van Wolffelaar
# Copyright © 2017-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::nmu;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::MoreUtils qw(any);
use List::Util qw(first);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $changelog_mentions_nmu = 0;
    my $changelog_mentions_local = 0;
    my $changelog_mentions_qa = 0;
    my $changelog_mentions_team_upload = 0;
    my $debian_dir = $processable->patched->resolve_path('debian/');
    my $chf;
    $chf = $debian_dir->child('changelog') if $debian_dir;

    # This isn't really an NMU check, but right now no other check
    # looks at debian/changelog in source packages.  Catch a
    # debian/changelog file that's a symlink.
    if ($chf and $chf->is_symlink) {
        $self->tag('changelog-is-symlink');
    }
    return unless $processable->changelog;

    # Get some data from the changelog file.
    my ($entry) = @{$processable->changelog->entries};
    my $uploader = canonicalize($entry->Maintainer // '');
    my $changes = $entry->Changes;
    $changes =~ s/^(\s*\n)+//;
    my $firstline = first { /^\s*\*/ } split('\n', $changes);

    # Check the first line for QA, NMU or team upload mentions.
    if ($firstline) {
        local $_ = $firstline;
        if (/\bnmu\b/i or /non-maintainer upload/i or m/LowThresholdNMU/i) {
            unless (
                m/
                        (?:ackno|\back\b|confir|incorporat).*
                        (?:\bnmu\b|non-maintainer)/xi
            ) {
                $changelog_mentions_nmu = 1;
            }
        }
        $changelog_mentions_local = 1 if /\blocal\s+package\b/i;
        $changelog_mentions_qa = 1 if /orphan/i or /qa (?:group )?upload/i;
        $changelog_mentions_team_upload = 1 if /team upload/i;
    }

    # If the version field is missing, assume it to be a native,
    # maintainer upload as it is probably the most likely case.
    my $version = $processable->field('version', '0-1');
    my $maintainer = canonicalize($processable->field('maintainer', ''));
    my $uploaders = $processable->field('uploaders');

    my $version_nmuness = 0;
    my $version_local = 0;
    my $upload_is_backport = $version =~ m/~bpo(\d+)\+(\d+)$/;

    if ($uploader =~ m/^\s|\s$/) {
        $self->tag('extra-whitespace-around-name-in-changelog-trailer');

        # trim both ends
        $uploader =~ s/^\s+|\s+$//g;
    }

    if ($version =~ /-[^.-]+(\.[^.-]+)?(\.[^.-]+)?$/) {
        $version_nmuness = 1 if defined $1;
        $version_nmuness = 2 if defined $2;
    }
    if ($version =~ /\+nmu\d+$/) {
        $version_nmuness = 1;
    }
    if ($version =~ /\+b\d+$/) {
        $version_nmuness = 2;
    }
    if ($version =~ /local/i) {
        $version_local = 1;
    }

    my $upload_is_nmu = $uploader ne $maintainer;
    if (defined $uploaders) {
        my @uploaders = map { canonicalize($_) } split />\K\s*,\s*/,$uploaders;
        $upload_is_nmu = 0 if any { $_ eq $uploader } @uploaders;
    }
    # If the changelog entry is missing a maintainer (eg. "-- <blank>")
    # assume it's an upload still work in progress.
    $upload_is_nmu = 0 if not $uploader;

    if ($maintainer =~ /packages\@qa.debian.org/) {
        $self->tag('orphaned-package-should-not-have-uploaders')
          if defined $uploaders;
        $self->tag('qa-upload-has-incorrect-version-number', $version)
          if $version_nmuness == 1;
        $self->tag('changelog-should-mention-qa') if !$changelog_mentions_qa;
    } elsif ($changelog_mentions_team_upload) {
        $self->tag('team-upload-has-incorrect-version-number', $version)
          if $version_nmuness == 1;
        $self->tag('unnecessary-team-upload') unless $upload_is_nmu;
    } else {
        # Local packages may be either NMUs or not.
        unless ($changelog_mentions_local || $version_local) {
            $self->tag('changelog-should-mention-nmu')
              if !$changelog_mentions_nmu && $upload_is_nmu;
            $self->tag('source-nmu-has-incorrect-version-number', $version)
              if $upload_is_nmu
              && $version_nmuness != 1
              && !$upload_is_backport;
        }
        $self->tag('changelog-should-not-mention-nmu')
          if $changelog_mentions_nmu && !$upload_is_nmu;
        $self->tag('maintainer-upload-has-incorrect-version-number', $version)
          if !$upload_is_nmu && $version_nmuness;
    }

    return;
}

# Canonicalize a maintainer address with respect to case.  E-mail addresses
# are case-insensitive in the right-hand side.
sub canonicalize {
    my ($maintainer) = @_;
    $maintainer =~ s/<([^>\@]+\@)([\w.-]+)>/<$1\L$2>/;
    return $maintainer;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
