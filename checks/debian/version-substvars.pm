# debian/version-substvars -- lintian check script -*- perl -*-
#
# Copyright © 2006 Adeodato Simó
# Copyright © 2019 Chris Lamb <lamby@debian.org>
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

# SUMMARY
# =======
#
# What breaks
# -----------
#
# (b1) any -> any (= ${source:Version})          -> use b:V
# (b2) any -> all (= ${binary:Version}) [or S-V] -> use s:V
# (b3) all -> any (= ${either-of-them})          -> use (>= ${s:V}),
#                                                   optionally (<< ${s:V}.1~)
#
# Note (b2) also breaks if (>= ${binary:Version}) [or S-V] is used.
#
# Always warn on ${Source-Version} even if it doesn't break since the substvar
# is now considered deprecated.

package Lintian::debian::version_substvars;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::MoreUtils qw(any);

use Lintian::Relation qw(:constants);
use Lintian::Util qw($PKGNAME_REGEX);

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my @dep_fields
      = qw(Depends Pre-Depends Recommends Suggests Conflicts Replaces);

    my @provided;
    foreach my $pkg ($processable->debian_control->installables) {
        my $val
          = $processable->debian_control->installable_fields($pkg)
          ->value('Provides');
        $val =~ s/^\s+|\s+$//g;
        push(@provided, split(/\s*,\s*/, $val));
    }

    foreach my $pkg1 ($processable->debian_control->installables) {
        my ($pkg1_is_any, $pkg2, $pkg2_is_any, $substvar_strips_binNMU);

        $pkg1_is_any= ($processable->debian_control->installable_fields($pkg1)
              ->value('Architecture') ne 'all');

        foreach my $field (@dep_fields) {
            next
              unless $processable->debian_control->installable_fields($pkg1)
              ->declares($field);
            my $rel = $processable->binary_relation($pkg1, $field);
            my $svid = 0;
            my $visitor = sub {
                if (/\$[{]Source-Version[}]/ and not $svid) {
                    $svid++;
                    $self->hint('substvar-source-version-is-deprecated',$pkg1);
                }
                if (
                    m/^($PKGNAME_REGEX)(?: :[-a-z0-9]+)? \s*   # pkg-name $1
                       \(\s*[\>\<]?[=\>\<]\s*                  # REL 
                        (\$[{](?:source:|binary:)(?:Upstream-)?Version[}]) # {subvar}
                     /x
                ) {
                    my $other = $1;
                    my $substvar = $2;
                    # We can't test dependencies on packages whose names are
                    # formed via substvars expanded during the build.  Assume
                    # those maintainers know what they're doing.
                    $self->hint('version-substvar-for-external-package',
                        "$pkg1 -> $other")
                      unless $processable->debian_control->installable_fields(
                        $other)->declares('Architecture')
                      or any { "$other (= $substvar)" eq $_ } @provided
                      or $other =~ /\$\{\S+\}/;
                }
            };
            $rel->visit($visitor, VISIT_PRED_FULL);
        }

        foreach (
            split(
                m/,/,
                (
                    $processable->debian_control->installable_fields($pkg1)
                      ->value('Pre-Depends')

                      .', '
                      . $processable->debian_control->installable_fields($pkg1)
                      ->value('Depends')))
        ) {
            next
              unless m/($PKGNAME_REGEX)(?: :any)? \s*               # pkg-name
                       \(\s*(\>)?=\s*                               # rel
                       \$[{]((?:Source-|source:|binary:)Version)[}] # subvar
                      /x;

            my $gt = $2//'';
            $pkg2 = $1;
            $substvar_strips_binNMU = ($3 eq 'source:Version');

            if (
                not $processable->debian_control->installable_fields($pkg2)
                ->declares('Architecture')) {
                # external relation or subst var package - either way,
                # handled above.
                next;
            }
            $pkg2_is_any
              = ($processable->debian_control->installable_fields($pkg2)
                  ->value('Architecture') ne 'all');

            if ($pkg1_is_any) {
                if ($pkg2_is_any and $substvar_strips_binNMU) {
                    unless ($gt) {
                        # (b1) any -> any (= ${source:Version})
                        $self->hint('not-binnmuable-any-depends-any',
                            "$pkg1 -> $pkg2");
                    } else {
                        # any -> any (>= ${source:Version})
                        # technically this can be "binNMU'ed", though it is
                        # a bit weird.
                        1;
                    }
                } elsif (not $pkg2_is_any) {
                    # (b2) any -> all ( = ${binary:Version}) [or S-V]
                    # or  -- same --  (>= ${binary:Version}) [or S-V]
                    $self->hint('not-binnmuable-any-depends-all',
                        "$pkg1 -> $pkg2")
                      if not $substvar_strips_binNMU;
                    if ($substvar_strips_binNMU and not $gt) {
                        $self->hint('maybe-not-arch-all-binnmuable',
                            "$pkg1 -> $pkg2");
                    }
                }
            } elsif ($pkg2_is_any && !$gt) {
                # (b3) all -> any (= ${either-of-them})
                $self->hint('not-binnmuable-all-depends-any',"$pkg1 -> $pkg2");
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
