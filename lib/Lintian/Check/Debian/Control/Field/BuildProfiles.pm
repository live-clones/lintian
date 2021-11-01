# debian/control/field/build-profiles -- lintian check script -*- perl -*-
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

package Lintian::Check::Debian::Control::Field::BuildProfiles;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;

    my $KNOWN_BUILD_PROFILES
      = $self->profile->load_data('fields/build-profiles');

    for my $installable ($control->installables) {
        my $installable_fields = $control->installable_fields($installable);

        my $field = 'Build-Profiles';

        my $raw = $installable_fields->value($field);
        next
          unless $raw;

        if (
            $raw!~ m{^\s*              # skip leading whitespace
                     <                 # first list start
                       !?[^\s<>]+      # (possibly negated) term
                       (?:             # any additional terms
                         \s+           # start with a space
                         !?[^\s<>]+    # (possibly negated) term
                       )*              # zero or more additional terms
                     >                 # first list end
                     (?:               # any additional restriction lists
                       \s+             # start with a space
                       <               # additional list start
                         !?[^\s<>]+    # (possibly negated) term
                         (?:           # any additional terms
                           \s+         # start with a space
                           !?[^\s<>]+  # (possibly negated) term
                         )*            # zero or more additional terms
                       >               # additional list end
                     )*                # zero or more additional lists
                     \s*$              # trailing spaces at the end
              }x
        ) {
            $self->hint(
                'invalid-restriction-formula-in-build-profiles-field',
                $raw,
                "(in section for $installable)",
                $LEFT_SQUARE_BRACKET
                  . 'debian/control:'
                  . $installable_fields->position($field)
                  . $RIGHT_SQUARE_BRACKET
            );

        } else {
            # parse the field and check the profile names
            $raw =~ s/^\s*<(.*)>\s*$/$1/;

            for my $restrlist (split />\s+</, $raw) {
                for my $profile (split /\s+/, $restrlist) {

                    $profile =~ s/^!//;

                    $self->hint(
                        'invalid-profile-name-in-build-profiles-field',
                        $profile,
                        "(in section for $installable)",
                        $LEFT_SQUARE_BRACKET
                          . 'debian/control:'
                          . $installable_fields->position($field)
                          . $RIGHT_SQUARE_BRACKET
                      )
                      unless $KNOWN_BUILD_PROFILES->recognizes($profile)
                      || $profile =~ /^pkg\.[a-z0-9][a-z0-9+.-]+\../;
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
