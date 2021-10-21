# -*- perl -*-
# Lintian::Relation::Predicate -- relationship predicates

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2004-2009 Russ Allbery <rra@debian.org>
# Copyright © 2018 Chris Lamb <lamby@debian.org>
# Copyright © 2020-2021 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Relation::Predicate;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Lintian::Relation::Version qw(:all);

use Moo;
use namespace::clean;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $COLON => q{:};

const my $EQUAL => q{=};
const my $LESS_THAN => q{<};
const my $LESS_THAN_OR_EQUAL => q{<=};
const my $DOUBLE_LESS_THAN => q{<<};
const my $GREATER_THAN => q{>};
const my $GREATER_THAN_OR_EQUAL => q{>=};
const my $DOUBLE_GREATER_THAN => q{>>};

const my $LEFT_PARENS => q{(};
const my $RIGHT_PARENS => q{)};
const my $LEFT_SQUARE => q{[};
const my $RIGHT_SQUARE => q{]};
const my $LEFT_ANGLE => q{<};
const my $RIGHT_ANGLE => q{>};

const my $TRUE => 1;
const my $FALSE => 0;

=head1 NAME

Lintian::Relation::Predicate - Lintian type for relationship predicates

=head1 SYNOPSIS

    use Lintian::Relation::Predicate;

=head1 DESCRIPTION

This module provides functions for parsing and evaluating package
relationships such as Depends and Recommends for binary packages and
Build-Depends for source packages.  It parses a relationship into an
internal format and can then answer questions such as "does this
dependency require that a given package be installed" or "is this
relationship a superset of another relationship."

=head1 INSTANCE METHODS

=over 4

=item literal

=item C<parsable>

=item name

=item multiarch_acceptor

=item version_operator

=item reference_version

=item build_architecture

=item build_profile

=cut

has literal => (
    is => 'rw',
    default => $EMPTY,
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); });

has parsable => (is => 'rw', default => $FALSE);

has name => (
    is => 'rw',
    default => $EMPTY,
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); });

has multiarch_acceptor => (
    is => 'rw',
    default => $EMPTY,
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); });

has version_operator => (
    is => 'rw',
    default => $EMPTY,
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); });

has reference_version => (
    is => 'rw',
    default => $EMPTY,
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); });

has build_architecture => (
    is => 'rw',
    default => $EMPTY,
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); });

has build_profile => (
    is => 'rw',
    default => $EMPTY,
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); });

=item parse

=cut

# The internal parser which converts a single package element of a
# relationship into the parsed form used for later processing.  We permit
# substvars to be used as package names so that we can use these routines with
# the unparsed debian/control file.
sub parse {
    my ($self, $text, $with_restrictions) = @_;

    $with_restrictions //= $TRUE;

    # store the element as-is, so we can reconstitute it later
    $self->literal($text);

    if (
        $text =~ m{
        ^\s*                            # skip leading whitespace
        (                               # package name or substvar (1)
         (?:                            #  start of the name
          [a-zA-Z0-9][a-zA-Z0-9+.-]*    #   start of a package name
          |                             #   or
          \$\{[a-zA-Z0-9:-]+\}          #   substvar
         )                              #  end of start of the name
         (?:                            #  substvars may be mixed in
          [a-zA-Z0-9+.-]+               #   package name portion
          |                             #   or
          \$\{[a-zA-Z0-9:-]+\}          #   substvar
         )*                             #  zero or more portions or substvars
        )                               # end of package name or substvar
        (?:[:]([a-z0-9-]+))?            # optional Multi-arch arch specification (2)
        (?:                             # start of optional version
         \s* \(                         # open parenthesis for version part
         \s* (<<|<=|>=|>>|[=<>])        # relation part (3)
         \s* ([^\)]+)                   # version (4)
         \s* \)                         # closing parenthesis
        )?                              # end of optional version
        (?:                             # start of optional architecture
         \s* \[                         # open bracket for architecture
         \s* ([^\]]+)                   # architectures (5)
         \s* \]                         # closing bracket
        )?                              # end of optional architecture
        (?:                             # start of optional restriction
          \s* <                         # open bracket for restriction
          \s* ([^,]+)                   # don't parse restrictions now
          \s* >                         # closing bracket
        )?                              # end of optional restriction
    \s* $}x
    ) {
        $self->parsable($TRUE);

        $self->name($1);
        $self->multiarch_acceptor($2);
        $self->version_operator($3);
        $self->reference_version($4);
        $self->build_architecture($5);
        $self->build_profile($6);

        $self->reference_version($EMPTY)
          unless length $self->version_operator;

        $self->version_operator($DOUBLE_LESS_THAN)
          if $self->version_operator eq $LESS_THAN;

        $self->version_operator($DOUBLE_GREATER_THAN)
          if $self->version_operator eq $GREATER_THAN;

        unless ($with_restrictions) {
            $self->version_operator($EMPTY);
            $self->reference_version($EMPTY);
            $self->build_architecture($EMPTY);
            $self->build_profile($EMPTY);
        }
    }

    return;
}

=item satisfies

=cut

# This internal function does the heavily lifting of comparing two
# elements.
#
# Takes two elements and returns true iff the second can be deduced from the
# first.  If the second is falsified by the first (in other words, if self
# actually satisfies not other), return 0.  Otherwise, return undef.  The 0 return
# is used by implies_element_inverse.
sub satisfies {
    my ($self, $other) = @_;

    if (!$self->parsable || !$other->parsable) {

        return 1
          if $self->to_string eq $other->to_string;

        return undef;
    }

    # If the names don't match, there is no relationship between them.
    return undef
      if $self->name ne $other->name;

    # the restriction formula forms a disjunctive normal form expression one
    # way to check whether A <dnf1> satisfies A <dnf2> is to check:
    #
    # if dnf1 == dnf1 OR dnf2:
    #     the second dependency is superfluous because the first dependency
    #     applies in all cases the second one applies
    #
    # an easy way to check for equivalence of the two dnf expressions would be
    # to construct the truth table for both expressions ("dnf1" and "dnf1 OR
    # dnf2") for all involved profiles and then comparing whether they are
    # equal
    #
    # the size of the truth tables grows with 2 to the power of the amount of
    # involved profile names but since there currently only exist six possible
    # profile names (see data/fields/build-profiles) that should be okay
    #
    # FIXME: we are not doing this check yet so if we encounter a dependency
    # with build profiles we assume that one does not satisfy the other:

    return undef
      if length $self->build_profile
      || length $other->build_profile;

    # If the names match, then the only difference is in the architecture or
    # version clauses.  First, check architecture.  The architectures for self
    # must be a superset of the architectures for other.
    my @self_arches = split($SPACE, $self->build_architecture);
    my @other_arches = split($SPACE, $other->build_architecture);
    if (@self_arches || @other_arches) {
        my $self_arch_neg = @self_arches && $self_arches[0] =~ /^!/;
        my $other_arch_neg = @other_arches && $other_arches[0] =~ /^!/;

  # If self has no arches, it is a superset of other and we should fall through
  # to the version check.
        if (not @self_arches) {
            # nothing
        }

     # If other has no arches, it is a superset of self and there are no useful
     # implications.
        elsif (not @other_arches) {

            return undef;
        }

        # Both have arches.  If neither are negated, we know nothing useful
        # unless other is a subset of self.
        elsif (not $self_arch_neg and not $other_arch_neg) {
            my %self_arches = map { $_ => 1 } @self_arches;
            my $subset = 1;
            for my $arch (@other_arches) {
                $subset = 0 unless $self_arches{$arch};
            }

            return undef
              unless $subset;
        }

       # If both are negated, we know nothing useful unless self is a subset of
       # other (and therefore has fewer things excluded, and therefore is more
       # general).
        elsif ($self_arch_neg and $other_arch_neg) {
            my %other_arches = map { $_ => 1 } @other_arches;
            my $subset = 1;
            for my $arch (@self_arches) {
                $subset = 0 unless $other_arches{$arch};
            }

            return undef
              unless $subset;
        }

       # If other is negated and self isn't, we'd need to know the full list of
       # arches to know if there's any relationship, so bail.
        elsif (not $self_arch_neg and $other_arch_neg) {

            return undef;
        }

# If self is negated and other isn't, other is a subset of self iff none of the
# negated arches in self are present in other.
        elsif ($self_arch_neg and not $other_arch_neg) {
            my %other_arches = map { $_ => 1 } @other_arches;
            my $subset = 1;
            for my $arch (@self_arches) {
                $subset = 0 if $other_arches{substr($arch, 1)};
            }

            return undef
              unless $subset;
        }
    }

    # Multi-arch architecture specification

    # According to the spec, only the special value "any" is allowed
    # and it is "recommended" to consider "other such package
    # relations as unsatisfiable".  That said, there seem to be an
    # interest in supporting ":<arch>" as well, so we will (probably)
    # have to accept those as well.
    #
    # Other than that, we would need to know that the package has the
    # field "Multi-arch: allowed", but we cannot check that here.  So
    # we assume that it is okay.

    # pkg has no chance of satisfing pkg:Y unless Y is 'any'
    return undef
      if !length $self->multiarch_acceptor
      && length $other->multiarch_acceptor
      && $other->multiarch_acceptor ne 'any';

    # TODO: Review this case.  Are there cases where other cannot
    # disprove self due to the ":any"-qualifier?  For now, we
    # assume there are no such cases.
    # pkg:X has no chance of satisfying pkg
    return undef
      if length $self->multiarch_acceptor
      && !length $other->multiarch_acceptor;

    # For now assert that only the identity holds.  In practise, the
    # "pkg:X" (for any valid value of X) seems to satisfy "pkg:any",
    # fixing that is a TODO (because version clauses complicates
    # matters)
    # pkg:X has no chance of satisfying pkg:Y unless X equals Y
    return undef
      if length $self->multiarch_acceptor
      && length $other->multiarch_acceptor
      && $self->multiarch_acceptor ne $other->multiarch_acceptor;

  # Now, down to version.  The implication is true if self's clause is stronger
  # than other's, or is equivalent.

    # If other has no version clause, then self's clause is always stronger.
    return 1
      unless length $other->version_operator;

# If other does have a version clause, then self must also have one to have any
# useful relationship.
    return undef
      unless length $self->version_operator;

 # other wants an exact version, so self must provide that exact version.  self
 # disproves other if other's version is outside the range enforced by self.
    if ($other->version_operator eq $EQUAL) {
        if ($self->version_operator eq $DOUBLE_LESS_THAN) {
            return versions_lte($self->reference_version,
                $other->reference_version) ? 0 : undef;
        } elsif ($self->version_operator eq $LESS_THAN_OR_EQUAL) {
            return versions_lt($self->reference_version,
                $other->reference_version) ? 0 : undef;
        } elsif ($self->version_operator eq $DOUBLE_GREATER_THAN) {
            return versions_gte($self->reference_version,
                $other->reference_version) ? 0 : undef;
        } elsif ($self->version_operator eq $GREATER_THAN_OR_EQUAL) {
            return versions_gt($self->reference_version,
                $other->reference_version) ? 0 : undef;
        } elsif ($self->version_operator eq $EQUAL) {
            return versions_equal($self->reference_version,
                $other->reference_version) ? 1 : 0;
        }
    }

# A greater than clause may disprove a less than clause.  Otherwise, if
# self's clause is <<, <=, or =, the version must be <= other's to satisfy other.
    if ($other->version_operator eq $LESS_THAN_OR_EQUAL) {
        if ($self->version_operator eq $DOUBLE_GREATER_THAN) {
            return versions_gte($self->reference_version,
                $other->reference_version) ? 0 : undef;
        } elsif ($self->version_operator eq $GREATER_THAN_OR_EQUAL) {
            return versions_gt($self->reference_version,
                $other->reference_version) ? 0 : undef;
        } elsif ($self->version_operator eq $EQUAL) {
            return versions_lte($self->reference_version,
                $other->reference_version) ? 1 : 0;
        } else {
            return versions_lte($self->reference_version,
                $other->reference_version) ? 1 : undef;
        }
    }

    # Similar, but << is stronger than <= so self's version must be << other's
    # version if the self relation is <= or =.
    if ($other->version_operator eq $DOUBLE_LESS_THAN) {
        if (   $self->version_operator eq $DOUBLE_GREATER_THAN
            || $self->version_operator eq $GREATER_THAN_OR_EQUAL) {
            return versions_gte($self->reference_version,
                $self->reference_version) ? 0 : undef;
        } elsif ($self->version_operator eq $DOUBLE_LESS_THAN) {
            return versions_lte($self->reference_version,
                $other->reference_version) ? 1 : undef;
        } elsif ($self->version_operator eq $EQUAL) {
            return versions_lt($self->reference_version,
                $other->reference_version) ? 1 : 0;
        } else {
            return versions_lt($self->reference_version,
                $other->reference_version) ? 1 : undef;
        }
    }

    # Same logic as above, only inverted.
    if ($other->version_operator eq $GREATER_THAN_OR_EQUAL) {
        if ($self->version_operator eq $DOUBLE_LESS_THAN) {
            return versions_lte($self->reference_version,
                $other->reference_version) ? 0 : undef;
        } elsif ($self->version_operator eq $LESS_THAN_OR_EQUAL) {
            return versions_lt($self->reference_version,
                $other->reference_version) ? 0 : undef;
        } elsif ($self->version_operator eq $EQUAL) {
            return versions_gte($self->reference_version,
                $other->reference_version) ? 1 : 0;
        } else {
            return versions_gte($self->reference_version,
                $other->reference_version) ? 1 : undef;
        }
    }
    if ($other->version_operator eq $DOUBLE_GREATER_THAN) {
        if (   $self->version_operator eq $DOUBLE_LESS_THAN
            || $self->version_operator eq $LESS_THAN_OR_EQUAL) {
            return versions_lte($self->reference_version,
                $other->reference_version) ? 0 : undef;
        } elsif ($self->version_operator eq $DOUBLE_GREATER_THAN) {
            return versions_gte($self->reference_version,
                $other->reference_version) ? 1 : undef;
        } elsif ($self->version_operator eq $EQUAL) {
            return versions_gt($self->reference_version,
                $other->reference_version) ? 1 : 0;
        } else {
            return versions_gt($self->reference_version,
                $other->reference_version) ? 1 : undef;
        }
    }

    return undef;
}

=item satisfies_inverse

=cut

# This internal function does the heavy lifting of inverse implication between
# two elements.  Takes two elements and returns true iff the falsehood of
# the second can be deduced from the truth of the first.  In other words, self
# satisfies not other, or restated, other satisfies not self.  (Since if a satisfies b, not b
# satisfies not a.)  Due to the return value of implies_element(), we can let it
# do most of the work.
sub satisfies_inverse {
    my ($self, $other) = @_;

    my $result = $self->satisfies($other);
    return undef
      if !defined $result;

    return $result ? 0 : 1;
}

=item to_string

=cut

sub to_string {
    my ($self) = @_;

    # return the original value
    return $self->literal
      unless $self->parsable;

    my $text = $self->name;

    $text .= $COLON . $self->multiarch_acceptor
      if length $self->multiarch_acceptor;

    $text
      .= $SPACE
      . $LEFT_PARENS
      . $self->version_operator
      . $SPACE
      . $self->reference_version
      . $RIGHT_PARENS
      if length $self->version_operator;

    $text.= $SPACE . $LEFT_SQUARE . $self->build_architecture . $RIGHT_SQUARE
      if length $self->build_architecture;

    $text .= $SPACE . $LEFT_ANGLE . $self->build_profile . $RIGHT_ANGLE
      if length $self->build_profile;

    return $text;
}

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
