# debian/version-substvars -- lintian check script -*- perl -*-
#
# Copyright © 2006 Adeodato Simó
# Copyright © 2019 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Debian::VersionSubstvars;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any uniq);

use Lintian::Relation;
use Lintian::Util qw($PKGNAME_REGEX);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $EQUAL => q{=};

sub source {
    my ($self) = @_;

    my $debian_control = $self->processable->debian_control;

    my @provides;
    push(@provides,
        $debian_control->installable_fields($_)
          ->trimmed_list('Provides', qr/\s*,\s*/))
      for $debian_control->installables;

    for my $installable ($debian_control->installables) {

        my $installable_control
          = $debian_control->installable_fields($installable);

        for my $field (
            qw(Depends Pre-Depends Recommends Suggests Conflicts Replaces)) {

            next
              unless $installable_control->declares($field);

            my $position = $installable_control->position($field);

            my $relation
              = $self->processable->binary_relation($installable, $field);

            $self->hint('substvar-source-version-is-deprecated',
                $installable, $field, "(line $position)")
              if $relation->matches(qr/\$[{]Source-Version[}]/);

            my %external;
            my $visitor = sub {
                my ($value) = @_;

                if (
                    $value
                    =~m{^($PKGNAME_REGEX)(?: :[-a-z0-9]+)? \s*   # pkg-name $1
                       \(\s*[\>\<]?[=\>\<]\s*                  # REL 
                        (\$[{](?:source:|binary:)(?:Upstream-)?Version[}]) # {subvar}
                     }x
                ) {
                    my $other = $1;
                    my $substvar = $2;

                    $external{$substvar} //= [];
                    push(@{ $external{$substvar} }, $other);
                }
            };
            $relation->visit($visitor, Lintian::Relation::VISIT_PRED_FULL);

            for my $substvar (keys %external) {
                for my $other (uniq @{ $external{$substvar} }) {

                    # We can't test dependencies on packages whose names are
                    # formed via substvars expanded during the build.  Assume
                    # those maintainers know what they're doing.
                    $self->hint(
                        'version-substvar-for-external-package',
                        $field,"(line $position)",
                        $substvar,"$installable -> $other"
                      )
                      unless $debian_control->installable_fields($other)
                      ->declares('Architecture')
                      || (any { "$other (= $substvar)" eq $_ } @provides)
                      || $other =~ /\$\{\S+\}/;
                }
            }
        }

        my @pre_depends
          = $installable_control->trimmed_list('Pre-Depends', qr/\s*,\s*/);
        my @depends
          = $installable_control->trimmed_list('Depends', qr/\s*,\s*/);

        for my $versioned (uniq(@pre_depends, @depends)) {

            next
              unless $versioned
              =~m{($PKGNAME_REGEX)(?: :any)? \s*               # pkg-name
                       \(\s*([>]?=)\s*                               # rel
                       \$[{]((?:Source-|source:|binary:)Version)[}] # subvar
                      }x;

            my $prerequisite = $1;
            my $operator = $2;
            my $substvar = $3;

            my $prerequisite_control
              = $debian_control->installable_fields($prerequisite);

            # external relation or subst var package; handled above
            next
              unless $prerequisite_control->declares('Architecture');

            my $prerequisite_is_all
              = ($prerequisite_control->value('Architecture') eq 'all');
            my $installable_is_all
              = ($installable_control->value('Architecture') eq 'all');

            my $context = "$installable -> $prerequisite";

            # (b1) any -> any (= ${source:Version})
            $self->hint('not-binnmuable-any-depends-any', $context)
              if !$installable_is_all
              && !$prerequisite_is_all
              && $operator eq $EQUAL
              && $substvar eq 'source:Version';

            # (b2) any -> all (= ${binary:Version}) [or S-V]
            $self->hint('maybe-not-arch-all-binnmuable', $context)
              if !$installable_is_all
              && $prerequisite_is_all
              && $operator eq $EQUAL
              && $substvar eq 'source:Version';

            # (b2) any -> all (* ${binary:Version}) [or S-V]
            $self->hint('not-binnmuable-any-depends-all', $context)
              if !$installable_is_all
              && $prerequisite_is_all
              && $substvar ne 'source:Version';

            # (b3) all -> any (= ${either-of-them})
            $self->hint('not-binnmuable-all-depends-any', $context)
              if $installable_is_all
              && !$prerequisite_is_all
              && $operator eq $EQUAL;

            # any -> any (>= ${source:Version})
            # technically this can be "binNMU'ed", though it is
            # a bit weird.
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
