# fields/standards-version -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2008-2009 Russ Allbery
# Copyright © 2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Fields::StandardsVersion;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Date::Parse qw(str2time);
use List::SomeUtils qw(any first_value);
use POSIX qw(strftime);
use Sort::Versions;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $DOT => q{.};

const my $MAXIMUM_COMPONENTS_ANALYZED => 3;

const my $DATE_ONLY => '%Y-%m-%d';
const my $DATE_AND_TIME => '%Y-%m-%d %H:%M:%S UTC';

sub source {
    my ($self) = @_;

    return
      unless $self->processable->fields->declares('Standards-Version');

    my $compliance_standard
      = $self->processable->fields->value('Standards-Version');

    my @compliance_components = split(/[.]/, $compliance_standard);
    if (@compliance_components < $MAXIMUM_COMPONENTS_ANALYZED
        || any { !/^\d+$/ } @compliance_components) {

        $self->hint('invalid-standards-version', $compliance_standard);
        return;
    }

    $self->hint('standards-version', $compliance_standard);

    my ($compliance_major, $compliance_minor, $compliance_patch)
      = @compliance_components;
    my $compliance_normalized
      = $compliance_major. $DOT. $compliance_minor. $DOT. $compliance_patch;

    my $policy_releases = $self->profile->policy_releases;
    my $latest_standard = $policy_releases->latest_version;

    my ($latest_major, $latest_minor, $latest_patch)
      = split(/[.]/, $latest_standard, $MAXIMUM_COMPONENTS_ANALYZED);

    # a fourth digit is a non-normative change in policy
    my $latest_normalized
      = $latest_major . $DOT . $latest_minor . $DOT . $latest_patch;

    my $changelog_epoch;
    my $distribution;

    my ($entry) = @{$self->processable->changelog->entries};
    if (defined $entry) {
        $changelog_epoch = $entry->Timestamp;
        $distribution = $entry->Distribution;
    }

    # assume recent date if there is no changelog; activates most tags
    $changelog_epoch //= $policy_releases->epoch($latest_standard);
    $distribution //= $EMPTY;

    unless ($policy_releases->is_known($compliance_standard)) {

        # could be newer
        if (versioncmp($compliance_standard, $latest_standard) == 1) {

            $self->hint('newer-standards-version',
                "$compliance_standard (current is $latest_standard)")
              unless $distribution =~ /backports/;

        } else {
            $self->hint('invalid-standards-version', $compliance_standard);
        }

        return;
    }

    my $compliance_epoch = $policy_releases->epoch($compliance_standard);

    my $changelog_date = strftime($DATE_ONLY, gmtime $changelog_epoch);
    my $compliance_date = strftime($DATE_ONLY, gmtime $compliance_epoch);

    my $changelog_timestamp= strftime($DATE_AND_TIME, gmtime $changelog_epoch);
    my $compliance_timestamp
      = strftime($DATE_AND_TIME, gmtime $compliance_epoch);

    # catch packages dated prior to release of their standard
    if ($compliance_epoch > $changelog_epoch) {

        # show precision if needed
        my $warp_illustration = "($changelog_date < $compliance_date)";
        $warp_illustration = "($changelog_timestamp < $compliance_timestamp)"
          if $changelog_date eq $compliance_date;

        $self->hint('timewarp-standards-version', $warp_illustration)
          unless $distribution eq 'UNRELEASED';
    }

    my @newer_versions = List::SomeUtils::before {
        $policy_releases->epoch($_) <= $compliance_epoch
    }
    @{$policy_releases->ordered_versions};

    # a fourth digit is a non-normative change in policy
    my @newer_normative_versions
      = grep { /^ \d+ [.] \d+ [.] \d+ (?:[.] 0)? $/sx } @newer_versions;

    my @newer_normative_epochs
      = map { $policy_releases->epoch($_) } @newer_normative_versions;

    my @normative_epochs_then_known
      = grep { $_ <= $changelog_epoch } @newer_normative_epochs;

    my $outdated_illustration
      = "$compliance_standard (released $compliance_date) (current is $latest_standard)";

    # use normative to prevent tag changes on minor new policy edits
    $self->hint('out-of-date-standards-version', $outdated_illustration)
      if @normative_epochs_then_known;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
