# fields/distribution -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2017-2019 Chris Lamb <lamby@debian.org>
# Copyright © 2020 Felix Lechner
#
# This program is free software.  It is distributed under the terms of
# the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any
# later version.
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

package Lintian::Check::Fields::Distribution;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any none);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };

sub changes {
    my ($self) = @_;

    my @distributions
      = $self->processable->fields->trimmed_list('Distribution');

    $self->hint('multiple-distributions-in-changes-file',
        join($SPACE, @distributions))
      if @distributions > 1;

    my @targets = grep { $_ ne 'UNRELEASED' } @distributions;

    # Strip common "extensions" for distributions
    # (except sid and experimental, where they would
    # make no sense)
    my %major;
    for my $target (@targets) {

        my $reduced = $target;
        $reduced =~ s{- (?:backports(?:-sloppy)?
                                   |lts
                                   |proposed(?:-updates)?
                                   |updates
                                   |security
                                   |volatile)$}{}xsm;

        $major{$target} = $reduced;
    }

    my $KNOWN_DISTS = $self->profile->load_data('changes-file/known-dists');

    my @unknown = grep { !$KNOWN_DISTS->recognizes($major{$_}) } @targets;
    $self->hint('bad-distribution-in-changes-file', $_) for @unknown;

    my @new_version = qw(sid unstable experimental);
    my $upload_lc = List::Compare->new(\@targets, \@new_version);

    my @regular = $upload_lc->get_intersection;
    my @special = $upload_lc->get_Lonly;

    # from Parse/DebianChangelog.pm
    # the changelog entries in the changes file are in a
    # different format than in the changelog, so the standard
    # parsers don't work. We just need to know if there is
    # info for more than 1 entry, so we just copy part of the
    # parse code here
    my $changes = $self->processable->fields->value('Changes');

    # count occurrences
    my @changes_versions
      = ($changes =~/^(?: \.)?\s*\S+\s+\(([^\(\)]+)\)\s+\S+/mg);

    my $version = $self->processable->fields->value('Version');
    my $distnumber;
    my $bpoversion;
    if ($version=~ /~bpo(\d+)\+(\d+)$/) {
        $distnumber = $1;
        $bpoversion = $2;

        $self->hint('upload-has-backports-version-number', $version, $_)
          for @regular;
    }

    my @backports = grep { /backports/ } @targets;
    for my $target (@backports) {

        $self->hint('backports-upload-has-incorrect-version-number',
            $version, $target)
          if (!defined $distnumber || !defined $bpoversion)
          || ($major{$target} eq 'squeeze' && $distnumber ne '60')
          || ($target eq 'wheezy-backports' && $distnumber ne '70')
          || ($target eq 'wheezy-backports-sloppy' && $distnumber ne '7')
          || ($major{$target} eq 'jessie' && $distnumber ne '8');

        # for a ~bpoXX+2 or greater version, there
        # probably will be only a single changelog entry
        $self->hint('backports-changes-missing')
          if ($bpoversion // 0) < 2 && @changes_versions == 1;
    }

    my $first_line = $changes;

    # advance to first non-empty line
    $first_line =~ s/^\s+//s;

    my $multiple;
    if ($first_line =~ /^\s*\S+\s+\([^\(\)]+\)([^;]+);/){
        $multiple = $1;
    }

    my @changesdists = split($SPACE, $multiple // $EMPTY);
    return
      unless @changesdists;

    # issue only when not mentioned in the Distribution field
    if ((any { $_ eq 'UNRELEASED' } @changesdists)
        && none { $_ eq 'UNRELEASED' } @distributions) {

        $self->hint('unreleased-changes');
        return;
    }

    my $mismatch_lc = List::Compare->new(\@distributions, \@changesdists);
    my @from_distribution = $mismatch_lc->get_Lonly;
    my @from_changes = $mismatch_lc->get_Ronly;

    if (@from_distribution || @from_changes) {

        if (any { $_ eq 'experimental' } @from_changes) {
            $self->hint('distribution-and-experimental-mismatch');

        } else {
            $self->hint('distribution-and-changes-mismatch',
                join($SPACE, @from_distribution, @from_changes));
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
