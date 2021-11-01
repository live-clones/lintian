# debian/control/prerequisite/development -- lintian check script -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2020 Chris Lamb <lamby@debian.org>
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Check::Debian::Control::Prerequisite::Development;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;

    for my $installable ($control->installables) {
        my $installable_fields = $control->installable_fields($installable);

        next
          unless $installable =~ /-dev$/;

        my $field = 'Depends';

        next
          unless $installable_fields->declares($field);

        my @depends
          = $installable_fields->trimmed_list($field, qr{ \s* , \s* }x);

        for my $other ($control->installables) {

            next
              if $other =~ /-(?:dev|docs?|common)$/;

            next
              unless $other =~ /^lib[\w.+-]+\d/;

            my @relevant
              = grep { m{ (?: ^ | [\s|] ) \Q$other\E (?: [\s|(] | \z ) }x }
              @depends;

            # If there are any alternatives here, something special is
            # going on.  Assume that the maintainer knows what they're
            # doing.  Otherwise, separate out just the versions.
            next
              if any { m{ [|] }x } @relevant;

            my @unsorted;
            for my $package (@relevant) {

                $package =~ m{^ [\w.+-]+ \s* [(] ([^)]+) [)] }x;
                push(@unsorted, ($1 // $EMPTY));
            }

            my @versions = sort @unsorted;

            my $context;

            # If there's only one mention of this package, the dependency
            # should be tight.  Otherwise, there should be both >>/>= and
            # <</<= dependencies that mention the source, binary, or
            # upstream version.  If there are more than three mentions of
            # the package, again something is weird going on, so we assume
            # they know what they're doing.
            if (@relevant == 1) {
                unless ($versions[0]
                    =~ /^\s*=\s*\$\{(?:binary:Version|Source-Version)\}/) {
                    # Allow "pkg (= ${source:Version})" if (but only if)
                    # the target is an arch:all package.  This happens
                    # with a lot of mono-packages.
                    #
                    # Note, we do not check if the -dev package is
                    # arch:all as well.  The version-substvars check
                    # handles that for us.
                    next
                      if $control->installable_fields($other)
                      ->value('Architecture') eq 'all'
                      && $versions[0]
                      =~ m{^ \s* = \s* \$[{]source:Version[}] }x;

                    $context = $relevant[0];
                }

            } elsif (@relevant == 2) {
                unless (
                    $versions[0] =~ m{^ \s* <[=<] \s* \$[{]
                        (?: (?:binary|source):(?:Upstream-)?Version
                            | Source-Version) [}] }xsm
                    && $versions[1] =~ m{^ \s* >[=>] \s* \$[{]
                        (?: (?:binary|source):(?:Upstream-)?Version
                        | Source-Version) [}] }xsm
                ) {
                    $context = "$relevant[0], $relevant[1]";
                }
            }

            $self->hint(
                'weak-library-dev-dependency',
                $field,
                $context,
                "(in section for $installable)",
                $LEFT_SQUARE_BRACKET
                  . 'debian/control:'
                  . $installable_fields->position($field)
                  . $RIGHT_SQUARE_BRACKET
            ) if length $context;
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
