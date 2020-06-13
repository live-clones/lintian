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

package Lintian::fields::distribution;

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::Data;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $KNOWN_DISTS = Lintian::Data->new('changes-file/known-dists');

sub changes {
    my ($self) = @_;

    my $original = $self->processable->field('Distribution');
    return
      unless defined $original;

    my @list = split(/\s+/, $original);

    $self->tag('multiple-distributions-in-changes-file', $original)
      if @list > 1;

    for my $element (@list) {

        next
          if $element eq 'UNRELEASED';

        my $dist = $element;
        if ($dist !~ m/^(?:sid|unstable|experimental)/) {
            # Strip common "extensions" for distributions
            # (except sid and experimental, where they would
            # make no sense)
            $dist =~ s/- (?:backports(?:-sloppy)?
                                   |lts
                                   |proposed(?:-updates)?
                                   |updates
                                   |security
                                   |volatile)$//xsm;

            if ($element =~ /backports/) {
                my $bpo1 = 1;
                if ($self->processable->field('Version')
                    =~ m/~bpo(\d+)\+(\d+)$/) {
                    my $distnumber = $1;
                    my $bpoversion = $2;
                    if (
                        ($dist eq 'squeeze' && $distnumber ne '60')
                        ||(    $element eq 'wheezy-backports'
                            && $distnumber ne '70')
                        ||(    $element eq 'wheezy-backports-sloppy'
                            && $distnumber ne '7')
                        ||($dist eq 'jessie' && $distnumber ne '8')
                    ) {
                        $self->tag(
                            'backports-upload-has-incorrect-version-number',
                            $self->processable->field('Version'),$element);
                    }
                    $bpo1 = 0 if ($bpoversion > 1);
                } else {
                    $self->tag('backports-upload-has-incorrect-version-number',
                        $self->processable->field('Version'));
                }
                # for a ~bpoXX+2 or greater version, there
                # probably will be only a single changelog entry
                if ($bpo1) {
                    my $changes_versions = 0;
                    foreach my $change_line (
                        split("\n", $self->processable->field('Changes'))){
                      # from Parse/DebianChangelog.pm
                      # the changelog entries in the changes file are in a
                      # different format than in the changelog, so the standard
                      # parsers don't work. We just need to know if there is
                      # info for more than 1 entry, so we just copy part of the
                      # parse code here
                        if ($change_line
                            =~ m/^\s*(?:\w[-+0-9a-z.]*) \((?:[^\(\) \t]+)\)(?:(?:\s+[-+0-9a-z.]+)+)\;\s*(?:.*)$/i
                        ) {
                            $changes_versions++;
                        }
                    }
                    # only complain if there is a single entry,
                    # if we didn't find any changelog entry, there is
                    # probably something wrong with the parsing, so we
                    # don't emit a tag
                    if ($changes_versions == 1) {
                        $self->tag('backports-changes-missing');
                    }
                }
            }
        } else {
            $self->tag('upload-has-backports-version-number',
                $self->processable->field('Version'),$element)
              if $self->processable->field('Version')=~ m/~bpo(\d+)\+(\d+)$/;
        }
        if (!$KNOWN_DISTS->known($dist)) {
            # bad distribution entry
            $self->tag('bad-distribution-in-changes-file',$element);
        }

        my $changes = $self->processable->field('Changes');
        if (defined $changes) {
            # take the first non-empty line
            $changes =~ s/^\s+//s;
            $changes =~ s/\n.*//s;

            if ($changes
                =~ m/^\s*(?:\w[-+0-9a-z.]*)\s*\([^\(\) \t]+\)\s*([-+0-9A-Za-z.]+)\s*;/
            ) {
                my $changesdist = $1;
                if ($changesdist eq 'UNRELEASED') {
                    $self->tag('unreleased-changes');
                } elsif ($changesdist ne $element
                    && $changesdist ne $dist) {
                    if (   $changesdist eq 'experimental'
                        && $dist ne 'experimental') {
                        $self->tag('distribution-and-experimental-mismatch',
                            $element);
                    } elsif ($KNOWN_DISTS->known($dist)) {
                        $self->tag('distribution-and-changes-mismatch',
                            $element, $changesdist);
                    }
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
