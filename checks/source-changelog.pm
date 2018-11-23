# source-changelog -- lintian check script -*- perl -*-

# Copyright (C) 2017 Chris Lamb <lamby@debian.org>
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

package Lintian::source_changelog;
use strict;
use warnings;
use autodie;
use Parse::DebianChangelog;
use Lintian::Tags qw(tag);

sub parse_version {

    my ($literal, $native) = @_;

    my $epoch;
    my $upstream;
    my $debian;
    my $source_nmu;
    my $binary_nmu;

    my $epoch_pattern      = qr/([^:\s]+)/;
    my $upstream_pattern   = qr/(\S+?)/;
    my $debian_pattern     = qr/([^-\s]+?)/;
    my $source_nmu_pattern = qr/(\S+)/;
    my $bin_nmu_pattern    = qr/([0-9]+)/;

    my $revision_pattern;

    # these capture two matches each
    $revision_pattern = qr/(?:-$debian_pattern(?:\.$source_nmu_pattern)?)?/
      if !$native;
    $revision_pattern = qr/()(?:\+nmu$source_nmu_pattern)?/
      if $native;

    my $pattern
      = qr/^/
      . qr/(?:$epoch_pattern:)?/
      . qr/$upstream_pattern/
      . qr/$revision_pattern/
      . qr/(?:\+b$bin_nmu_pattern)?/. qr/$/;

    ($epoch, $upstream, $debian, $source_nmu, $binary_nmu)
      = ($literal =~ $pattern);

    my $revision = '';

    $revision = "+nmu$source_nmu" if $native && length $source_nmu;
    $revision = "-$debian" . (length $source_nmu ? ".$source_nmu" : '')
      if !$native && length $debian;

    my $reconstructed
      = (length $epoch ? "$epoch:" : '')
      . $upstream
      . $revision
      . (length $binary_nmu ? "+b$binary_nmu" : '');

    my $version = {
        Literal => $literal,
        Epoch => $epoch,
        Upstream => $upstream,
        Debian => $debian,
        SourceNMU => $source_nmu,
        BinaryNMU => $binary_nmu
    };

    return ($version, $reconstructed);
}

sub run {
    my ($pkg, undef, $info, undef, undef) = @_;

    my @entries = $info->changelog->data;

    if (@entries > 0) {
        my ($latest_version, $reconstructed)
          =parse_version $entries[0]->Version, $info->native;

        tag 'malformed-debian-changelog-version', $latest_version->{Literal},
          $reconstructed
          if $reconstructed ne $latest_version->{Literal};

        if ($latest_version->{Upstream} =~ /-/g > 0) {
            tag 'hyphen-in-upstream-part-of-debian-changelog-version',
              $latest_version->{Upstream}
              unless $info->native;
            tag 'hyphen-in-native-debian-changelog-version',
              $latest_version->{Upstream}
              if $info->native;
        }

        tag 'debian-changelog-version-requires-debian-revision',
          $latest_version->{Literal}
          unless length $latest_version->{Debian} || $info->native;
    }

    if (@entries > 1) {
        my $first_timestamp = $entries[0]->Timestamp;
        my $second_timestamp = $entries[1]->Timestamp;

        if ($first_timestamp && $second_timestamp) {
            tag 'latest-debian-changelog-entry-without-new-date'
              unless ($first_timestamp - $second_timestamp) > 0
              || lc($entries[0]->Distribution) eq 'unreleased';
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
