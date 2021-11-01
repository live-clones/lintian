# debian/control/field/relation -- lintian check script -*- perl -*-
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

package Lintian::Check::Debian::Control::Field::Relation;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any none first_value);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $COLON => q{:};
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};
const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

const my $ARROW => q{->};

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;
    my $source_fields = $control->source_fields;

    # Check that fields which should be comma-separated or
    # pipe-separated have separators.  Places where this tends to
    # cause problems are with wrapped lines such as:
    #
    #     Depends: foo, bar
    #      baz
    #
    # or with substvars.  If two substvars aren't separated by a
    # comma, but at least one of them expands to an empty string,
    # there will be a lurking bug.  The result will be syntactically
    # correct, but as soon as both expand into something non-empty,
    # there will be a syntax error.
    #
    # The architecture list can contain things that look like packages
    # separated by spaces, so we have to remove any architecture
    # restrictions first.  This unfortunately distorts our report a
    # little, but hopefully not too much.
    #
    # Also check for < and > relations.  dpkg-gencontrol warns about
    # them and then transforms them in the output to <= and >=, but
    # it's easy to miss the error message.  Similarly, check for
    # duplicates, which dpkg-source eliminates.

    for my $field (
        qw(Build-Depends Build-Depends-Indep
        Build-Conflicts Build-Conflicts-Indep)
    ) {
        next
          unless $source_fields->declares($field);

        my $position = $source_fields->position($field);
        my $pointer = "(in source paragraph) [debian/control:$position]";

        my @values = $source_fields->trimmed_list($field, qr{ \s* , \s* }x);
        my @obsolete = grep { m{ [(] [<>] \s* [^<>=]+ [)] }x } @values;

        $self->hint('obsolete-relation-form-in-source', $field, $_, $pointer)
          for @obsolete;

        my $raw = $source_fields->value($field);
        my $relation = Lintian::Relation->new->load($raw);

        for my $redundant_set ($relation->redundancies) {

            $self->hint(
                'redundant-control-relation', $field,
                join(', ', sort @{$redundant_set}), $pointer
            );
        }

        $self->check_separators('source', $raw, $pointer);
    }

    for my $installable ($control->installables) {
        my $installable_fields = $control->installable_fields($installable);

        for my $field (
            qw(Pre-Depends Depends Recommends Suggests Breaks
            Conflicts Provides Replaces Enhances)
        ) {
            next
              unless $installable_fields->declares($field);

            my $position = $installable_fields->position($field);
            my $pointer
              = "(in section for $installable) [debian/control:$position]";

            my @values
              = $installable_fields->trimmed_list($field, qr{ \s* , \s* }x);
            my @obsolete = grep { m{ [(] [<>] \s* [^<>=]+ [)] }x } @values;

            $self->hint('obsolete-relation-form-in-source',
                $field, $_, $pointer)
              for @obsolete;

            my $relation
              = $self->processable->binary_relation($installable, $field);

            for my $redundant_set ($relation->redundancies) {

                $self->hint(
                    'redundant-control-relation', $field,
                    join(', ', sort @{$redundant_set}), $pointer
                );
            }

            my $raw = $installable_fields->value($field);
            $self->check_separators($installable, $raw, $pointer);
        }
    }

    return;
}

sub check_separators {
    my ($self, $package, $string, $pointer) = @_;

    $string =~ s/\n(\s)/$1/g;
    $string =~ s/\[[^\]]*\]//g;

    if (
        $string =~ m{(?:^|\s)
                   (
                (?:\w[^\s,|\$\(]+|\$\{\S+:Depends\})\s*
                (?:\([^\)]*\)\s*)?
                   )
                   \s+
                   (
                (?:\w[^\s,|\$\(]+|\$\{\S+:Depends\})\s*
                (?:\([^\)]*\)\s*)?
                   )}x
    ) {
        my ($prev, $next) = ($1, $2);

        # trim right
        $prev =~ s/\s+$//;
        $next =~ s/\s+$//;

        $self->hint('missing-separator-between-items',
            "'$prev' and '$next'", $pointer);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
