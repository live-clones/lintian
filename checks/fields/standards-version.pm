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

package Lintian::Check::fields::standards_version;

use v5.20;
use warnings;
use utf8;
use autodie;

use Const::Fast;
use Date::Parse qw(str2time);
use List::Util qw(first);
use POSIX qw(strftime);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    return
      unless $processable->fields->declares('Standards-Version');

    # Any Standards Version released before this day is "ancient"
    my $ANCIENT_DATE_DATA = $self->profile->load_data(
        'standards-version/ancient-date',
        qr{\s*<\s*},
        sub {
            my $date = str2time($_[1])
              or die "Cannot parse ANCIENT_DATE: $!";
            return $date;
        });

    my $ANCIENT_DATE = $ANCIENT_DATE_DATA->value('ANCIENT')
      or die 'Cannot get ANCIENT_DATE';

    my $policy_releases = $self->profile->policy_releases;

 # In addition to the normal Lintian::Data structure, we also want a list of
 # all standards and their release dates so that we can check things like the
 # release date of the standard released after the one a package declared.  Do
 # that by pulling all data out of the Lintian::Data structure and sorting it
 # by release date.  We can also use this to get the current standards version.
    my $latest_standard = $policy_releases->latest_version;

    # catalogued versions are presently normalized to four components
    $latest_standard =~ s{\.0$}{};

    my ($latest_major, $latest_minor, $latest_patch)
      = split(m{\.}, $latest_standard, 3);

    my $release_epoch = $policy_releases->epoch($latest_standard);

    # udebs aren't required to conform to policy, so they don't need
    # Standards-Version. (If they have it, though, it should be valid.)
    my $version = $processable->fields->value('Standards-Version');

    my $all_udeb = 1;
    $all_udeb = 0
      if first {
        $processable->debian_control->installable_package_type($_) ne 'udeb'
    }
    $processable->debian_control->installables;

    # Check basic syntax and strip off the fourth digit.  People are allowed to
    # include the fourth digit if they want, but it indicates a non-normative
    # change in Policy and is therefore meaningless in the Standards-Version
    # field.
    unless ($version =~ m/^\s*(\d+\.\d+\.\d+)(?:\.\d+)?\s*$/) {
        $self->hint('invalid-standards-version', $version);
        return;
    }
    my $stdver = $1;
    my ($major, $minor, $patch) = $stdver =~ m/^(\d+)\.(\d+)\.(\d+)/;

    # To do some date checking, we have to get the package date from
    # the changelog file.  If we can't find the changelog file, assume
    # that the package was released today, since that activates the
    # most tags.
    my ($pkgdate, $dist);
    if (defined $processable->changelog) {
        my ($entry) = @{$processable->changelog->entries};
        $pkgdate
          = ($entry && $entry->Timestamp) ? $entry->Timestamp : $release_epoch;
        $dist= ($entry && $entry->Distribution)? $entry->Distribution : $EMPTY;
    } else {
        $pkgdate = $release_epoch;
    }

    # Check for packages dated prior to the date of release of the standards
    # version with which they claim to comply.
    if (   defined $dist
        && $dist ne 'UNRELEASED'
        && $policy_releases->is_known($stdver)
        && $policy_releases->epoch($stdver) > $pkgdate) {

        my $package = strftime('%Y-%m-%d', gmtime $pkgdate);
        my $release
          = strftime('%Y-%m-%d', gmtime $policy_releases->epoch($stdver));
        if ($package eq $release) {
            # Increase the precision if required
            my $fmt = '%Y-%m-%d %H:%M:%S UTC';
            $package = strftime($fmt, gmtime $pkgdate);
            $release = strftime($fmt, gmtime $policy_releases->epoch($stdver));
        }
        $self->hint('timewarp-standards-version', "($package < $release)");
    }

    $self->hint('standards-version', $version);

    if (not $policy_releases->is_known($stdver)) {
        # Unknown standards version.  Perhaps newer?
        if (
               $major > $latest_major
            || ($major == $latest_major && $minor > $latest_minor)
            || (   $major == $latest_major
                && $minor == $latest_minor
                && $patch > $latest_patch)
        ) {
            $self->hint('newer-standards-version',
                "$version (current is $latest_standard)")
              unless $dist =~ /backports/;
        } else {
            $self->hint('invalid-standards-version', $version);
        }

    } elsif ($stdver eq $latest_standard) {
        # Current standard.  Nothing more to check.
        return;

    } else {
        # Otherwise, we need to see if the standard that this package
        # declares is both new enough to not be ancient and was the
        # current standard at the time the package was uploaded.
        #
        # A given standards version is considered obsolete if the
        # version following it has been out for at least two years (so
        # the current version is never obsolete).
        my $rdate = $policy_releases->epoch($stdver);
        my $released = strftime('%Y-%m-%d', gmtime $rdate);
        my $context
          = "$version (released $released) (current is $latest_standard)";

        if ($rdate < $ANCIENT_DATE) {
            $self->hint('ancient-standards-version', $context);

        } else {
            # We have to get the package date from the changelog file.  If we
            # can't find the changelog file, always issue the tag.
            unless (defined $processable->changelog) {
                $self->hint('out-of-date-standards-version', $context);
                return;
            }

            my ($entry) = @{$processable->changelog->entries};
            my $timestamp
              = ($entry && $entry->Timestamp) ? $entry->Timestamp : 0;

            for my $standard (@{$policy_releases->ordered_versions}) {

                last
                  if $standard eq $stdver;

                if ($policy_releases->epoch($standard) < $timestamp) {
                    $self->hint('out-of-date-standards-version', $context);
                    last;
                }
            }
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
