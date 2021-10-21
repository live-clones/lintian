# -*- perl -*-
# Lintian::Relation -- operations on dependencies and relationships

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2004-2009 Russ Allbery <rra@debian.org>
# Copyright © 2018 Chris Lamb <lamby@debian.org>
# Copyright © 2020 Felix Lechner
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

package Lintian::Relation;

use v5.20;
use warnings;
use utf8;

use Carp qw(confess);
use Const::Fast;
use List::SomeUtils qw(any);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation::Predicate;

use Moo;
use namespace::clean;

use constant {
    VISIT_PRED_NAME => 0,
    VISIT_PRED_FULL => 1,
    VISIT_OR_CLAUSE_FULL => 3,
    VISIT_STOP_FIRST_MATCH => 4,
};

const my $EMPTY => q{};

const my $BRANCH_TYPE => 0;
const my $PREDICATE => 1;

const my $FALSE => 0;

=head1 NAME

Lintian::Relation - Lintian operations on dependencies and relationships

=head1 SYNOPSIS

    my $depends = Lintian::Relation->new('foo | bar, baz');
    print encode_utf8("yes\n") if $depends->satisfies('baz');
    print encode_utf8("no\n") if $depends->satisfies('foo');

=head1 DESCRIPTION

This module provides functions for parsing and evaluating package
relationship fields such as Depends and Recommends for binary packages and
Build-Depends for source packages.  It parses a relationship into an
internal format and can then answer questions such as "does this
dependency require that a given package be installed" or "is this
relationship a superset of another relationship."

A dependency line is viewed as a predicate formula.  The comma separator
means "and", and the alternatives separator means "or".  A bare package
name is the predicate "a package of this name is available".  A package
name with a version clause is the predicate "a package of this name that
satisfies this version clause is available."  Architecture restrictions,
as specified in Policy for build dependencies, are supported and also
checked in the implication logic unless the new_norestriction()
constructor is used.  With that constructor, architecture restrictions
are ignored.

=head1 INSTANCE METHODS

=over 4

=item trunk

=cut

has trunk => (is => 'rw', default => sub { ['AND'] });

=item load (RELATION)

Creates a new Lintian::Relation object corresponding to the parsed
relationship RELATION.  This object can then be used to ask questions
about that relationship.  RELATION may be C<undef> or the empty string, in
which case the returned Lintian::Relation object is empty (always
satisfied).

=cut

sub load {
    my ($self, $condition, $with_restrictions) = @_;

    $condition //= $EMPTY;

    my @trunk = ('AND');

    my @requirements = grep { length } split(/\s*,\s*/, $condition);
    for my $requirement (@requirements) {

        my @predicates;

        my @alternatives = split(/\s*\|\s*/, $requirement);
        for my $alternative (@alternatives) {

            my $predicate = Lintian::Relation::Predicate->new;
            $predicate->parse($alternative, $with_restrictions);

            push(@predicates, ['PRED', $predicate]);
        }

        push(@trunk, @predicates)
          if @predicates == 1;

        push(@trunk, ['OR', @predicates])
          if @predicates > 1;
    }

    $self->trunk(\@trunk);

    return $self;
}

=item load_norestriction (RELATION)

Creates a new Lintian::Relation object corresponding to the parsed
relationship RELATION, ignoring architecture restrictions and restriction
lists. This should be used in cases where we only care if a dependency is
present in some cases and we don't want to require that the architectures
match (such as when checking for proper build dependencies, since if there
are architecture constraints the maintainer is doing something beyond
Lintian's ability to analyze) or that the restrictions list match (Lintian
can't handle dependency implications with build profiles yet).  RELATION
may be C<undef> or the empty string, in which case the returned
Lintian::Relation object is empty (always satisfied).

=cut

sub load_norestriction {
    my ($self, $condition) = @_;

    return $self->load($condition, $FALSE);
}

=item logical_and(RELATION, ...)

Creates a new Lintian::Relation object produced by AND'ing all the
relations together.  Semantically it is the similar to:

 Lintian::Relation->new (join (', ', @relations))

Except it can avoid some overhead and it works if some of the elements
are Lintian::Relation objects already.

=cut

sub logical_and {
    my ($self, @conditions) = @_;

    my @tree = ('AND');

    # make sure to add $self
    for my $condition (@conditions, $self) {

        my $relation;

        if (ref $condition eq $EMPTY) {
            # allow string conditions
            $relation = Lintian::Relation->new->load($condition);

        } else {
            $relation = $condition;
        }

        next
          if $relation->is_empty;

        if (   $tree[$BRANCH_TYPE] eq 'AND'
            && $relation->trunk->[$BRANCH_TYPE] eq 'AND') {

            my @anded = @{$relation->trunk};
            shift @anded;
            push(@tree, @anded);

        } else {
            push(@tree, $relation->trunk);
        }
    }

    my $created = Lintian::Relation->new;
    $created->trunk(\@tree);

    return $created;
}

=item redundancies()

Returns a list of duplicated elements within the relation object.  Each
element of the returned list will be a reference to an anonymous array
holding a set of relations considered redundancies of each other.  Two
relations are considered redundancies if one satisfies the other, meaning that
if one relationship is satisfied, the other is necessarily satisfied.
This relationship does not have to be commutative: the opposite
implication may not hold.

=cut

sub redundancies {
    my ($self) = @_;

    # there are no redundancies unless the top-level relationship is AND.
    return ()
      unless $self->trunk->[$BRANCH_TYPE] eq 'AND';

# The logic here is a bit complex in order to merge sets of duplicate
# dependencies.  We want foo (<< 2), foo (>> 1), foo (= 1.5) to end up as
# one set of redundancies, even though the first doesn't satisfy the second.
#
# $redundant_sets holds a hash, where the key is the earliest dependency in a set
# and the value is a hash whose keys are the other dependencies in the
# set.  $seen holds a map from package names to the duplicate sets that
# they're part of, if they're not the earliest package in a set.  If
# either of the dependencies in a duplicate pair were already seen, add
# the missing one of the pair to the existing set rather than creating a
# new one.
    my %redundant_sets;

    my @remaining = @{$self->trunk};

    # discard AND identifier
    shift @remaining;
    my $i = 1;

    my %seen;
    while (@remaining > 1) {

        my $branch_i = shift @remaining;
        my $j = $i + 1;

        # run against all others
        for my $branch_j (@remaining) {

            my $forward = implies_array($branch_i, $branch_j);
            my $reverse = implies_array($branch_j, $branch_i);

            if ($forward or $reverse) {
                my $one = $self->to_string($branch_i);
                my $two = $self->to_string($branch_j);

                if ($seen{$one}) {
                    $redundant_sets{$seen{$one}}{$two} = $j;
                    $seen{$two} = $seen{$one};

                } elsif ($seen{$two}) {
                    $redundant_sets{$seen{$two}}{$one} = $i;
                    $seen{$one} = $seen{$two};

                } else {
                    $redundant_sets{$one} ||= {};
                    $redundant_sets{$one}{$two} = $j;
                    $seen{$two} = $one;
                }
            }
        } continue {
            $j++;
        }
    } continue {
        $i++;
    }

    return map { [$_, keys %{ $redundant_sets{$_}}] } keys %redundant_sets;
}

=item restriction_less

Returns a restriction-less variant of this relation.

=cut

sub restriction_less {
    my ($self) = @_;

    my $unrestricted
      = Lintian::Relation->new->load_norestriction($self->to_string);

    return $unrestricted;
}

=item satisfies(RELATION)

Returns true if the relationship satisfies RELATION, meaning that if the
Lintian::Relation object is satisfied, RELATION will always be satisfied.
RELATION may be either a string or another Lintian::Relation object.

By default, architecture restrictions are honored in RELATION if it is a
string.  If architecture restrictions should be ignored in RELATION,
create a Lintian::Relation object with new_norestriction() and pass that
in as RELATION instead of the string.

=item implies_array

=cut

# This internal function does the heavy of AND, OR, and NOT logic.  It expects
# two references to arrays instead of an object and a relation.
sub implies_array {
    my ($p, $q) = @_;

    my $i;
    my $q0 = $q->[$BRANCH_TYPE];
    my $p0 = $p->[$BRANCH_TYPE];

    if ($q0 eq 'PRED') {
        if ($p0 eq 'PRED') {
            return $p->[$PREDICATE]->satisfies($q->[$PREDICATE]);
        } elsif ($p0 eq 'AND') {
            $i = 1;
            while ($i < @{$p}) {
                return 1 if implies_array($p->[$i++], $q);
            }
            return 0;
        } elsif ($p0 eq 'OR') {
            $i = 1;
            while ($i < @{$p}) {
                return 0 if not implies_array($p->[$i++], $q);
            }
            return 1;
        } elsif ($p0 eq 'NOT') {
            return implies_array_inverse($p->[1], $q);
        }
    } elsif ($q0 eq 'AND') {
        # Each of q's clauses must be deduced from p.
        $i = 1;
        while ($i < @{$q}) {
            return 0 if not implies_array($p, $q->[$i++]);
        }
        return 1;

    } elsif ($q0 eq 'OR') {
        # If p is something other than OR, p needs to satisfy one of the
        # clauses of q.  If p is an AND clause, q is satisfied if any of the
        # clauses of p satisfy it.
        #
        # The interesting case is OR.  In this case, do an OR to OR comparison
        # to determine if q's clause is a superset of p's clause as follows:
        # take each branch of p and see if it satisfies a branch of q.  If
        # each branch of p satisfies some branch of q, return 1.  Otherwise,
        # return 0.
        #
        # Simple logic that requires that p satisfy at least one of the
        # clauses of q considered in isolation will miss that a|b satisfies
        # a|b|c, since a|b doesn't satisfy any of a, b, or c in isolation.
        if ($p0 eq 'PRED') {
            $i = 1;
            while ($i < @{$q}) {
                return 1 if implies_array($p, $q->[$i++]);
            }
            return 0;
        } elsif ($p0 eq 'AND') {
            $i = 1;
            while ($i < @{$p}) {
                return 1 if implies_array($p->[$i++], $q);
            }
            return 0;
        } elsif ($p0 eq 'OR') {

            my @p_branches = @{$p};
            shift @p_branches;

            my @q_branches = @{$q};
            shift @q_branches;

            for my $p_branch (@p_branches) {

                return 0
                  unless any { implies_array($p_branch, $_) }
                @q_branches;
            }

            return 1;

        } elsif ($p->[$BRANCH_TYPE] eq 'NOT') {
            return implies_array_inverse($p->[1], $q);
        }

    } elsif ($q0 eq 'NOT') {
        if ($p0 eq 'NOT') {
            return implies_array($q->[1], $p->[1]);
        }
        return implies_array_inverse($p, $q->[1]);
    }

    return undef;
}

# The public interface.
sub satisfies {
    my ($self, $condition) = @_;

    my $relation;
    if (ref $condition eq $EMPTY) {
        # allow string conditions
        $relation = Lintian::Relation->new->load($condition);

    } else {
        $relation = $condition;
    }

    return implies_array($self->trunk, $relation->trunk) // 0;
}

=item satisfies_inverse(RELATION)

Returns true if the relationship satisfies that RELATION is certainly false,
meaning that if the Lintian::Relation object is satisfied, RELATION cannot
be satisfied.  RELATION may be either a string or another
Lintian::Relation object.

As with satisfies(), by default, architecture restrictions are honored in
RELATION if it is a string.  If architecture restrictions should be
ignored in RELATION, create a Lintian::Relation object with
new_norestriction() and pass that in as RELATION instead of the string.

=item implies_array_inverse

=cut

# This internal function does the heavily lifting for AND, OR, and NOT
# handling for inverse implications.  It takes two references to arrays and
# returns true iff the falsehood of the second can be deduced from the truth
# of the first.
sub implies_array_inverse {
    my ($p, $q) = @_;
    my $i;
    my $q0 = $q->[$BRANCH_TYPE];
    my $p0 = $p->[$BRANCH_TYPE];
    if ($q0 eq 'PRED') {
        if ($p0 eq 'PRED') {
            return $p->[$PREDICATE]->satisfies_inverse($q->[$PREDICATE]);
        } elsif ($p0 eq 'AND') {
            # q's falsehood can be deduced from any of p's clauses
            $i = 1;
            while ($i < @{$p}) {
                return 1 if implies_array_inverse($p->[$i++], $q);
            }
            return 0;
        } elsif ($p0 eq 'OR') {
            # q's falsehood must be deduced from each of p's clauses
            $i = 1;
            while ($i < @{$p}) {
                return 0 if not implies_array_inverse($p->[$i++], $q);
            }
            return 1;
        } elsif ($p0 eq 'NOT') {
            return implies_array($q, $p->[1]);
        }
    } elsif ($q0 eq 'AND') {
        # Any of q's clauses must be falsified by p.
        $i = 1;
        while ($i < @{$q}) {
            return 1 if implies_array_inverse($p, $q->[$i++]);
        }
        return 0;
    } elsif ($q0 eq 'OR') {
        # Each of q's clauses must be falsified by p.
        $i = 1;
        while ($i < @{$q}) {
            return 0 if not implies_array_inverse($p, $q->[$i++]);
        }
        return 1;
    } elsif ($q0 eq 'NOT') {
        return implies_array($p, $q->[1]);
    }

    return 0;
}

# The public interface.
sub satisfies_inverse {
    my ($self, $condition) = @_;

    my $relation;
    if (ref $condition eq $EMPTY) {
        # allow string conditions
        $relation = Lintian::Relation->new->load($condition);

    } else {
        $relation = $condition;
    }

    return implies_array_inverse($self->trunk, $relation->trunk) // 0;
}

=item to_string

Returns the textual form of a relationship.  This converts the internal
form back into the textual representation and returns that, not the
original argument, so the spacing is standardized.  Returns undef on
internal failures (such as an object in an unexpected format).

=cut

# The second argument isn't part of the public API.  It's a partial relation
# that's not a blessed object and is used by to_string() internally so that it
# can recurse.
sub to_string {
    my ($self, $branch) = @_;

    my $tree = $branch // $self->trunk;

    my $text;
    if ($tree->[$BRANCH_TYPE] eq 'PRED') {

        $text = $tree->[$PREDICATE]->to_string;

    } elsif ($tree->[$BRANCH_TYPE] eq 'AND' || $tree->[$BRANCH_TYPE] eq 'OR') {

        my $connector = ($tree->[$BRANCH_TYPE] eq 'AND') ? ', ' : ' | ';
        my @separated = map { $self->to_string($_) } @{$tree}[1 .. $#{$tree}];
        $text = join($connector, @separated);

    } elsif ($tree->[$BRANCH_TYPE] eq 'NOT') {

        # currently not generated by any relation
        $text = '! ' . $tree->[$PREDICATE]->to_string;

    } else {
        confess encode_utf8("Case $tree->[$BRANCH_TYPE] not implemented");
    }

    return $text;
}

=item matches (REGEX[, WHAT])

Check if one of the predicates in this relation matches REGEX.  WHAT
determines what is tested against REGEX and if not given, defaults to
VISIT_PRED_NAME.

This method will return a truth value if REGEX matches at least one
predicate or clause (as defined by the WHAT parameter - see below).

NOTE: Often L</satisfies> (or L</satisfies_inverse>) is a better choice
than this method.  This method should generally only be used when
checking for a "pattern" package (e.g. phpapi-[\d\w+]+).


WHAT can be one of:

=over 4

=item VISIT_PRED_NAME

Match REGEX against the package name in each predicate (i.e. version
and architecture constrains are ignored).  Each predicate is tested in
isolation.  As an example:

 my $rel = Lintian::Relation->new ('somepkg | pkg-0 (>= 1)');
 # Will match (version is ignored)
 $rel->matches (qr/^pkg-\d$/, VISIT_PRED_NAME);

=item VISIT_PRED_FULL

Match REGEX against the full (normalized) predicate (i.e. including
version and architecture).  Each predicate is tested in isolation.
As an example:

 my $vrel = Lintian::Relation->new ('somepkg | pkg-0 (>= 1)');
 my $uvrel = Lintian::Relation->new ('somepkg | pkg-0');

 # Will NOT match (does not match with version)
 $vrel->matches (qr/^pkg-\d$/, VISIT_PRED_FULL);
 # Will match (this relation does not have a version)
 $uvrel->matches (qr/^pkg-\d$/, VISIT_PRED_FULL);

 # Will match (but only because there is a version)
 $vrel->matches (qr/^pkg-\d \(.*\)$/, VISIT_PRED_FULL);
 # Will NOT match (there is no version in the relation)
 $uvrel->matches (qr/^pkg-\d  \(.*\)$/, VISIT_PRED_FULL);

=item VISIT_OR_CLAUSE_FULL

Match REGEX against the full (normalized) OR clause.  Each predicate
will have both version and architecture constrains present.  As an
example:


 my $vpred = Lintian::Relation->new ('pkg-0 (>= 1)');
 my $orrel = Lintian::Relation->new ('somepkg | pkg-0 (>= 1)');
 my $rorrel = Lintian::Relation->new ('pkg-0 (>= 1) | somepkg');

 # Will match
 $vrel->matches (qr/^pkg-\d(?: \([^\)]\))?$/, VISIT_OR_CLAUSE_FULL);
 # These Will NOT match (does not match the "|" and the "somepkg" part)
 $orrel->matches (qr/^pkg-\d(?: \([^\)]\))?$/, VISIT_OR_CLAUSE_FULL);
 $rorrel->matches (qr/^pkg-\d(?: \([^\)]\))?$/, VISIT_OR_CLAUSE_FULL);

=back

=cut

sub matches {
    my ($self, $regex, $what) = @_;
    $what //= VISIT_PRED_NAME;
    return $self->visit(sub { m/$regex/ }, $what | VISIT_STOP_FIRST_MATCH);
}

=item equals

Same for full-string matches. Satisfies the perlcritic policy
RegularExpressions::ProhibitFixedStringMatches.

=cut

sub equals {
    my ($self, $string, $what) = @_;
    $what //= VISIT_PRED_NAME;
    return $self->visit(sub { $_ eq $string }, $what | VISIT_STOP_FIRST_MATCH);
}

=item visit (CODE[, FLAGS])

Visit clauses or predicates of this relation.  Each clause or
predicate is passed to CODE as first argument and will be available as
C<$_>.

The optional bitmask parameter, FLAGS, can be used to control what is
visited and such.  If FLAGS is not given, it defaults to
VISIT_PRED_NAME.  The possible values of FLAGS are:

=over 4

=item VISIT_PRED_NAME

The package name in each predicate is visited, but the version and
architecture part(s) are left out (if any).

=item VISIT_PRED_FULL

The full predicates are visited in turn.  The predicate will be
normalized (by L</to_string>).

=item VISIT_OR_CLAUSE_FULL

CODE will be passed the full OR clauses of this relation.  The clauses
will be normalized (by L</to_string>)

Note: It will not visit the underlying predicates in the clause.

=item VISIT_STOP_FIRST_MATCH

Stop the visits the first time CODE returns a truth value.  This is
similar to L<first|List::Util/first>, except visit will return the
value returned by CODE.

=back

Except where a given flag specifies otherwise, the return value of
visit is last value returned by CODE (or C<undef> for the empty
relation).

=cut

# The last argument is not part of the public API.  It's a partial
# relation that's not a blessed object and is used by visit()
# internally so that it can recurse.

sub visit {
    my ($self, $code, $flags, $branch) = @_;

    my $tree = $branch // $self->trunk;
    my $rel_type = $tree->[$BRANCH_TYPE];

    $flags //= 0;

    if ($rel_type eq 'PRED') {
        my $predicate = $tree->[$PREDICATE];
        my $against = $predicate->name;
        $against = $predicate->to_string
          if $flags & VISIT_PRED_FULL;

        local $_ = $against;
        return scalar $code->($against);

    } elsif (($flags & VISIT_OR_CLAUSE_FULL) == VISIT_OR_CLAUSE_FULL
        and $rel_type eq 'OR') {

        my $against = $self->to_string($tree);

        local $_ = $against;
        return scalar $code->($against);

    } elsif ($rel_type eq 'AND'
        or $rel_type eq 'OR'
        or $rel_type eq 'NOT') {

        for my $rel (@{$tree}[1 .. $#{$tree}]) {
            my $ret = scalar $self->visit($code, $flags, $rel);
            if ($ret && ($flags & VISIT_STOP_FIRST_MATCH)) {
                return $ret;
            }
        }
        return 0;
    }

    return 0;
}

=item is_empty

Returns a truth value if this relation is empty (i.e. it contains no
predicates).

=cut

sub is_empty {
    my ($self) = @_;

    return 1
      if $self->trunk->[$BRANCH_TYPE] eq 'AND' && !$self->trunk->[1];

    return 0;
}

=item unparsable_predicates

Returns a list of predicates that were unparsable.

They are returned in the original textual representation and are also
sorted by said representation.

=cut

sub unparsable_predicates {
    my ($self) = @_;

    my @worklist = ($self->trunk);
    my @unparsable;

    while (my $current = pop(@worklist)) {

        my $rel_type = $current->[$BRANCH_TYPE];

        if ($rel_type ne 'PRED') {

            push(@worklist, @{$current}[1 .. $#{$current}]);
            next;
        }

        my $predicate = $current->[$PREDICATE];

        push(@unparsable, $predicate->literal)
          unless $predicate->parsable;
    }

    my @sorted = sort @unparsable;

    return @sorted;
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
