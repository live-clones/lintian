# -*- perl -*-
# Lintian::Relation -- operations on dependencies and relationships

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2004-2009 Russ Allbery <rra@debian.org>
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

use strict;
use warnings;

use constant {
    VISIT_PRED_NAME => 0,
    VISIT_PRED_FULL => 1,
    VISIT_OR_CLAUSE_FULL => 3,
    VISIT_STOP_FIRST_MATCH => 4,
};

use Exporter qw(import);
our (@EXPORT_OK, %EXPORT_TAGS);
%EXPORT_TAGS = (
    constants => [qw(VISIT_PRED_NAME VISIT_PRED_FULL VISIT_OR_CLAUSE_FULL
                     VISIT_STOP_FIRST_MATCH)],
);
@EXPORT_OK = (
    @{ $EXPORT_TAGS{constants} }
);

use Lintian::Relation::Version qw(:all);

=head1 NAME

Lintian::Relation - Lintian operations on dependencies and relationships

=head1 SYNOPSIS

    my $depends = Lintian::Relation->new('foo | bar, baz');
    print "yes\n" if $depends->implies('baz');
    print "no\n" if $depends->implies('foo');

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
checked in the implication logic unless the new_noarch() constructor is
used.  With that constructor, architecture restrictions are ignored.

=head1 CLASS METHODS

=over 4

=item new(RELATION)

Creates a new Lintian::Relation object corresponding to the parsed
relationship RELATION.  This object can then be used to ask questions
about that relationship.  RELATION may be C<undef> or the empty string, in
which case the returned Lintian::Relation object is empty (always
satisfied).

=cut

# The internal parser which converts a single package element of a
# relationship into the parsed form used for later processing.  We permit
# substvars to be used as package names so that we can use these routines with
# the unparsed debian/control file.
sub parse_element {
    my ($class, $element) = @_;
    $element =~ /
        ^\s*                            # skip leading whitespace
        (                               # package name or substvar (1)
         (?:                            #  start of the name
          [a-zA-Z0-9][a-zA-Z0-9+.-]+    #   start of a package name
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
         \s* (<<|<=|=|>=|>>|<|>)        # relation part (3)
         \s* (.*?)                      # version (4)
         \s* \)                         # closing parenthesis
        )?                              # end of optional version
        (?:                             # start of optional architecture
         \s* \[                         # open bracket for architecture
         \s* (.*?)                      # architectures (5)
         \s* \]                         # closing bracket
        )?                              # end of optional architecture
    /x;

    my ($pkgname, $march, $relop, $relver, $bdarch) = ($1, $2, $3, $4, $5);
    my @array;
    if (not defined($relop)) {
        # If there's no version, we don't need to do any further processing.
        # Otherwise, convert the legacy < and > relations to the current ones.
        @array = ('PRED', $pkgname, undef, undef, $bdarch, $march);
    } else {
        if ($relop eq '<') {
            $relop = '<<';
        } elsif ($relop eq '>') {
            $relop = '>>';
        }
        @array = ('PRED', $pkgname, $relop, $relver, $bdarch, $march);
    }

    # Optimise the memory usage of the array.  Understanding this
    # requires a bit of "Perl guts" knowledge.  Storing "undef" in an
    # array (or hash) actually creates a new empty "undefined" scalar.
    # This means that we pay the full overhead of Perl's SV struct for
    # each undef value in this array.
    #   Combine this with the fact that at least the BD-arch qualifier
    # is rare (in fact, always undef for binary relations) and
    # multi-arch qualifiers equally so (at least at the moment).
    # On unversioned relations, we end up paying for 4 (unique) empty
    # scalars.
    #   This overhead accumuates to 0.44M for the binary relations of
    # source:linux (on i386).
    #
    # Fortunately, perl allows us to do "out-of-bounds" access and
    # will simply return undef in this case.  This means, we can
    # basically get away with popping elements from the right hand
    # side of the array "for free".
    pop(@array) while (not defined($array[-1]));

    return \@array;
}

# Singleton "empty-relation" object.  Since these objects are immutable,
# there is no reason for having multiple "empty" objects.
my $EMPTY_RELATION = bless(['AND'], 'Lintian::Relation');

# Create a new Lintian::Relation object, parsing the argument into our
# internal format.
sub new {
    my ($class, $relation) = @_;
    $relation = '' unless defined($relation);
    my @result;
    for my $element (split(/\s*,\s*/o, $relation)) {
        next if $element eq '';
        my @alternatives;
        for my $alternative (split(/\s*\|\s*/o, $element)) {
            push(@alternatives, $class->parse_element($alternative));
        }
        if (@alternatives == 1) {
            push(@result, @alternatives);
        } else {
            push(@result, ['OR', @alternatives]);
        }
    }

    if ($class eq 'Lintian::Relation') {
        return $EMPTY_RELATION if not @result;
    }

    my $self;
    if (@result == 1) {
        $self = $result[0];
    } else {
        $self = ['AND', @result];
    }
    bless($self, $class);
    return $self;
}

=item new_noarch(RELATION)

Creates a new Lintian::Relation object corresponding to the parsed
relationship RELATION, ignoring architecture restrictions.  This should be
used in cases where we only care if a dependency is present in some cases
and we don't want to require that the architectures match (such as when
checking for proper build dependencies, since if there are architecture
constraints the maintainer is doing something beyond Lintian's ability to
analyze).  RELATION may be C<undef> or the empty string, in which case the
returned Lintian::Relation object is empty (always satisfied).

=cut

sub new_noarch {
    my ($class, $relation) = @_;
    $relation = '' unless defined($relation);
    $relation =~ s/\[[^\]]*\]//g;
    return $class->new($relation);
}


=item and(RELATION, ...)

Creates a new Lintian::Relation object produced by AND'ing all the
relations together.  Semantically it is the similar to:

 Lintian::Relation->new (join (', ', @relations))

Except it can avoid some overhead and it works if some of the elements
are Lintian::Relation objects already.

=cut

sub and {
    my ($class, @args) = @_;
    my @result;
    foreach my $arg (@args) {
        my $rel = $arg;
        unless ($arg && ref $arg eq 'Lintian::Relation') {
            # Optimize out empty entries.
            next unless $arg;
            $rel = Lintian::Relation->new ($arg);
        }
        if ($rel->[0] eq 'AND') {
            my @r = @$rel;
            push @result, @r[1..$#r];
        } else {
            push @result, $rel;
        }
    }

    if ($class eq 'Lintian::Relation') {
        return $EMPTY_RELATION if not @result;
    }

    my $self;
    if (@result == 1) {
        $self = $result[0];
    } else {
        $self = ['AND', @result];
    }
    bless ($self, $class);
    return $self;
}

=back

=head1 INSTANCE METHODS

=over 4

=item duplicates()

Returns a list of duplicated elements within the relation object.  Each
element of the returned list will be a reference to an anonymous array
holding a set of relations considered duplicates of each other.  Two
relations are considered duplicates if one implies the other, meaning that
if one relationship is satisfied, the other is necessarily satisfied.
This relationship does not have to be commutative: the opposite
implication may not hold.

=cut

sub duplicates {
    my ($self) = @_;

    # There are no duplicates unless the top-level relationship is AND.
    if ($self->[0] ne 'AND') {
        return ();
    }

    # The logic here is a bit complex in order to merge sets of duplicate
    # dependencies.  We want foo (<< 2), foo (>> 1), foo (= 1.5) to end up as
    # one set of duplicates, even though the first doesn't imply the second.
    #
    # $dups holds a hash, where the key is the earliest dependency in a set
    # and the value is a hash whose keys are the other dependencies in the
    # set.  $seen holds a map from package names to the duplicate sets that
    # they're part of, if they're not the earliest package in a set.  If
    # either of the dependencies in a duplicate pair were already seen, add
    # the missing one of the pair to the existing set rather than creating a
    # new one.
    my (%dups, %seen);
    for (my $i = 1; $i < @$self; $i++) {
        for (my $j = $i + 1; $j < @$self; $j++) {
            my $forward = $self->implies_array($self->[$i], $self->[$j]);
            my $reverse = $self->implies_array($self->[$j], $self->[$i]);
            if ($forward or $reverse) {
                my $first = $self->unparse($self->[$i]);
                my $second = $self->unparse($self->[$j]);
                if ($seen{$first}) {
                    $dups{$seen{$first}}->{$second} = $j;
                    $seen{$second} = $seen{$first};
                } elsif ($seen{$second}) {
                    $dups{$seen{$second}}->{$first} = $i;
                    $seen{$first} = $seen{$second};
                } else {
                    $dups{$first} ||= {};
                    $dups{$first}->{$second} = $j;
                    $seen{$second} = $first;
                }
            }
        }
    }

    # The sort maintains the original order in which we encountered the
    # dependencies, just in case that helps the user find the problems,
    # despite the fact we're using a hash.
    return map {
        [ $_,
          sort { $dups{$_}->{$a} <=> $dups{$_}->{$b} } keys %{ $dups{$_} }
        ]
    } keys %dups;
}

=item implies(RELATION)

Returns true if the relationship implies RELATION, meaning that if the
Lintian::Relation object is satisfied, RELATION will always be satisfied.
RELATION may be either a string or another Lintian::Relation object.

By default, architecture restrictions are honored in RELATION if it is a
string.  If architecture restrictions should be ignored in RELATION,
create a Lintian::Relation object with new_noarch() and pass that in as
RELATION instead of the string.

=cut

# This internal function does the heavily lifting of comparing two
# elements.
#
# Takes two elements and returns true iff the second can be deduced from the
# first.  If the second is falsified by the first (in other words, if p
# actually implies not q), return 0.  Otherwise, return undef.  The 0 return
# is used by implies_element_inverse.
sub implies_element {
    my ($self, $p, $q) = @_;

    # If the names don't match, there is no relationship between them.
    $$p[1] = '' unless defined $$p[1];
    $$q[1] = '' unless defined $$q[1];
    return if $$p[1] ne $$q[1];

    # If the names match, then the only difference is in the architecture or
    # version clauses.  First, check architecture.  The architectures for p
    # must be a superset of the architectures for q.
    my @p_arches = split(' ', defined($$p[4]) ? $$p[4] : '');
    my @q_arches = split(' ', defined($$q[4]) ? $$q[4] : '');
    if (@p_arches || @q_arches) {
        my $p_arch_neg = @p_arches && $p_arches[0] =~ /^!/;
        my $q_arch_neg = @q_arches && $q_arches[0] =~ /^!/;

        # If p has no arches, it is a superset of q and we should fall through
        # to the version check.
        if (not @p_arches) {
            # nothing
        }

        # If q has no arches, it is a superset of p and there are no useful
        # implications.
        elsif (not @q_arches) {
            return;
        }

        # Both have arches.  If neither are negated, we know nothing useful
        # unless q is a subset of p.
        elsif (not $p_arch_neg and not $q_arch_neg) {
            my %p_arches = map { $_ => 1 } @p_arches;
            my $subset = 1;
            for my $arch (@q_arches) {
                $subset = 0 unless $p_arches{$arch};
            }
            return unless $subset;
        }

        # If both are negated, we know nothing useful unless p is a subset of
        # q (and therefore has fewer things excluded, and therefore is more
        # general).
        elsif ($p_arch_neg and $q_arch_neg) {
            my %q_arches = map { $_ => 1 } @q_arches;
            my $subset = 1;
            for my $arch (@p_arches) {
                $subset = 0 unless $q_arches{$arch};
            }
            return unless $subset;
        }

        # If q is negated and p isn't, we'd need to know the full list of
        # arches to know if there's any relationship, so bail.
        elsif (not $p_arch_neg and $q_arch_neg) {
            return;
        }

        # If p is negated and q isn't, q is a subset of p iff none of the
        # negated arches in p are present in q.
        elsif ($p_arch_neg and not $q_arch_neg) {
            my %q_arches = map { $_ => 1 } @q_arches;
            my $subset = 1;
            for my $arch (@p_arches) {
                $subset = 0 if $q_arches{substr($arch, 1)};
            }
            return unless $subset;
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
    #
    # For now assert that only the identity holds.  In practise, the
    # "pkg:X" (for any valid value of X) seems to imply "pkg:any",
    # fixing that is a TODO (because version clauses complicates
    # matters)
    if (defined $$p[5]) {
        # Assume the identity to hold
        return unless defined $$q[5] and $$p[5] eq $$q[5];
    } elsif (defined $$q[5]) {
        return;
    }

    # Now, down to version.  The implication is true if p's clause is stronger
    # than q's, or is equivalent.

    # If q has no version clause, then p's clause is always stronger.
    return 1 if not defined $$q[2];

    # If q does have a version clause, then p must also have one to have any
    # useful relationship.
    return if not defined $$p[2];

    # q wants an exact version, so p must provide that exact version.  p
    # disproves q if q's version is outside the range enforced by p.
    if ($$q[2] eq '=') {
        if ($$p[2] eq '<<') {
            return versions_lte($$p[3], $$q[3]) ? 0 : undef;
        } elsif ($$p[2] eq '<=') {
            return versions_lt($$p[3], $$q[3]) ? 0 : undef;
        } elsif ($$p[2] eq '>>') {
            return versions_gte($$p[3], $$q[3]) ? 0 : undef;
        } elsif ($$p[2] eq '>=') {
            return versions_gt($$p[3], $$q[3]) ? 0 : undef;
        } elsif ($$p[2] eq '=') {
            return versions_equal($$p[3], $$q[3]);
        }
    }

    # A greater than clause may disprove a less than clause.  Otherwise, if
    # p's clause is <<, <=, or =, the version must be <= q's to imply q.
    if ($$q[2] eq '<=') {
        if ($$p[2] eq '>>') {
            return versions_gte($$p[3], $$q[3]) ? 0 : undef;
        } elsif ($$p[2] eq '>=') {
            return versions_gt($$p[3], $$q[3]) ? 0 : undef;
        } elsif ($$p[2] eq '=') {
            return versions_lte($$p[3], $$q[3]);
        } else {
            return versions_lte($$p[3], $$q[3]) ? 1 : undef;
        }
    }

    # Similar, but << is stronger than <= so p's version must be << q's
    # version if the p relation is <= or =.
    if ($$q[2] eq '<<') {
        if ($$p[2] eq '>>' or $$p[2] eq '>=') {
            return versions_gte($$p[3], $$p[3]) ? 0 : undef;
        } elsif ($$p[2] eq '<<') {
            return versions_lte($$p[3], $$q[3]);
        } elsif ($$p[2] eq '=') {
            return versions_lt($$p[3], $$q[3]);
        } else {
            return versions_lt($$p[3], $$q[3]) ? 1 : undef;
        }
    }

    # Same logic as above, only inverted.
    if ($$q[2] eq '>=') {
        if ($$p[2] eq '<<') {
            return versions_lte($$p[3], $$q[3]) ? 0 : undef;
        } elsif ($$p[2] eq '<=') {
            return versions_lt($$p[3], $$q[3]) ? 0 : undef;
        } elsif ($$p[2] eq '=') {
            return versions_gte($$p[3], $$q[3]);
        } else {
            return versions_gte($$p[3], $$q[3]) ? 1 : undef;
        }
    }
    if ($$q[2] eq '>>') {
        if ($$p[2] eq '<<' or $$p[2] eq '<=') {
            return versions_lte($$p[3], $$q[3]) ? 0 : undef;
        } elsif ($$p[2] eq '>>') {
            return versions_gte($$p[3], $$q[3]);
        } elsif ($$p[2] eq '=') {
            return versions_gt($$p[3], $$q[3]);
        } else {
            return versions_gt($$p[3], $$q[3]) ? 1 : undef;
        }
    }

    return;
}

# This internal function does the heavy of AND, OR, and NOT logic.  It expects
# two references to arrays instead of an object and a relation.
sub implies_array {
    my ($self, $p, $q) = @_;
    my $i;
    if ($q->[0] eq 'PRED') {
        if ($p->[0] eq 'PRED') {
            return $self->implies_element($p, $q);
        } elsif ($p->[0] eq 'AND') {
            $i = 1;
            while ($i < @$p) {
                return 1 if $self->implies_array($p->[$i++], $q);
            }
            return 0;
        } elsif ($p->[0] eq 'OR') {
            $i = 1;
            while ($i < @$p) {
                return 0 if not $self->implies_array($p->[$i++], $q);
            }
            return 1;
        } elsif ($p->[0] eq 'NOT') {
            return $self->implies_array_inverse($p->[1], $q);
        }
    } elsif ($q->[0] eq 'AND') {
        # Each of q's clauses must be deduced from p.
        $i = 1;
        while ($i < @$q) {
            return 0 if not $self->implies_array($p, $q->[$i++]);
        }
        return 1;
    } elsif ($q->[0] eq 'OR') {
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
        if ($p->[0] eq 'PRED') {
            $i = 1;
            while ($i < @$q) {
                return 1 if $self->implies_array($p, $q->[$i++]);
            }
            return 0;
        } elsif ($p->[0] eq 'AND') {
            $i = 1;
            while ($i < @$p) {
                return 1 if $self->implies_array($p->[$i++], $q);
            }
            return 0;
        } elsif ($p->[0] eq 'OR') {
            for ($i = 1; $i < @$p; $i++) {
                my $j = 1;
                my $satisfies = 0;
                while ($j < @$q) {
                    if ($self->implies_array($p->[$i], $q->[$j++])) {
                        $satisfies = 1;
                        last;
                    }
                }
                return 0 unless $satisfies;
            }
            return 1;
        } elsif ($p->[0] eq 'NOT') {
            return $self->implies_array_inverse($p->[1], $q);
        }
    } elsif ($q->[0] eq 'NOT') {
        if ($p->[0] eq 'NOT') {
            return $self->implies_array($q->[1], $p->[1]);
        }
        return $self->implies_array_inverse($p, $q->[1]);
    }
}

# The public interface.
sub implies {
    my ($self, $relation) = @_;
    if (ref($relation) ne 'Lintian::Relation') {
        $relation = Lintian::Relation->new($relation);
    }
    return $self->implies_array($self, $relation);
}

=item implies_inverse(RELATION)

Returns true if the relationship implies that RELATION is certainly false,
meaning that if the Lintian::Relation object is satisfied, RELATION cannot
be satisfied.  RELATION may be either a string or another
Lintian::Relation object.

As with implies(), by default, architecture restrictions are honored in
RELATION if it is a string.  If architecture restrictions should be
ignored in RELATION, create a Lintian::Relation object with new_noarch()
and pass that in as RELATION instead of the string.

=cut

# This internal function does the heavy lifting of inverse implication between
# two elements.  Takes two elements and returns true iff the falsehood of
# the second can be deduced from the truth of the first.  In other words, p
# implies not q, or resstated, q implies not p.  (Since if a implies b, not b
# implies not a.)  Due to the return value of implies_element(), we can let it
# do most of the work.
sub implies_element_inverse {
    my ($self, $p, $q) = @_;
    my $result = $self->implies_element($q, $p);

    return not $result if defined $result;
    return;
}

# This internal function does the heavily lifting for AND, OR, and NOT
# handling for inverse implications.  It takes two references to arrays and
# returns true iff the falsehood of the second can be deduced from the truth
# of the first.
sub implies_array_inverse {
    my ($self, $p, $q) = @_;
    my $i;
    if ($$q[0] eq 'PRED') {
        if ($$p[0] eq 'PRED') {
            return $self->implies_element_inverse($p, $q);
        } elsif ($$p[0] eq 'AND') {
            # q's falsehood can be deduced from any of p's clauses
            $i = 1;
            while ($i < @$p) {
                return 1 if $self->implies_array_inverse($$p[$i++], $q);
            }
            return 0;
        } elsif ($$p[0] eq 'OR') {
            # q's falsehood must be deduced from each of p's clauses
            $i = 1;
            while ($i < @$p) {
                return 0 if not $self->implies_array_inverse($$p[$i++], $q);
            }
            return 1;
        } elsif ($$p[0] eq 'NOT') {
            return $self->implies_array($q, $$p[1]);
        }
    } elsif ($$q[0] eq 'AND') {
        # Any of q's clauses must be falsified by p.
        $i = 1;
        while ($i < @$q) {
            return 1 if $self->implies_array_inverse($p, $$q[$i++]);
        }
        return 0;
    } elsif ($$q[0] eq 'OR') {
        # Each of q's clauses must be falsified by p.
        $i = 1;
        while ($i < @$q) {
            return 0 if not $self->implies_array_inverse($p, $$q[$i++]);
        }
        return 1;
    } elsif ($$q[0] eq 'NOT') {
        return $self->implies_array($p, $$q[1]);
    }
}

# The public interface.
sub implies_inverse {
    my ($self, $relation) = @_;
    if (ref($relation) ne 'Lintian::Relation') {
        $relation = Lintian::Relation->new($relation);
    }
    return $self->implies_array_inverse($self, $relation);
}

=item unparse()

Returns the textual form of a relationship.  This converts the internal
form back into the textual representation and returns that, not the
original argument, so the spacing is standardized.  Returns undef on
internal failures (such as an object in an unexpected format).

=cut

# The second argument isn't part of the public API.  It's a partial relation
# that's not a blessed object and is used by unparse() internally so that it
# can recurse.
#
# We also support a NOT predicate.  This currently isn't ever generated by a
# regular relation, but it may someday be useful.
sub unparse {
    my ($self, $partial) = @_;
    my $relation = defined($partial) ? $partial : $self;
    if ($relation->[0] eq 'PRED') {
        my $text = $relation->[1];
        if (defined $relation->[5]) {
            $text .= ":$relation->[5]";
        }
        if (defined $relation->[2]) {
            $text .= " ($relation->[2] $relation->[3])";
        }
        if (defined $relation->[4]) {
            $text .= " [$relation->[4]]";
        }
        return $text;
    } elsif ($relation->[0] eq 'AND' || $relation->[0] eq 'OR') {
        my $seperator = ($relation->[0] eq 'AND') ? ', ' : ' | ';
        my $text = '';
        for my $element (@$relation[1 .. $#$relation]) {
            $text .= $seperator if $text;
            my $result = $self->unparse($element);
            return unless defined($result);
            $text .= $result;
        }
        return $text;
    } elsif ($relation->[0] eq 'NOT') {
        return '! ' . $self->unparse($relation->[1]);
    } else {
        return;
    }
}

=item matches (REGEX[, WHAT])

Check if one of the predicates in this relation matches REGEX.  WHAT
determines what is tested against REGEX and if not given, defaults to
VISIT_PRED_NAME.

This method will return a truth value if REGEX matches at least one
predicate or clause (as defined by the WHAT parameter - see below).

NOTE: Often L</implies> (or L</implies_inverse>) is a better choice
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
 # Will NOT match (there is no verson in the relation)
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
    my ($self, $regex, $what, $partial) = @_;
    my $relation = $partial // $self;
    $what //= VISIT_PRED_NAME;
    return $self->visit ( sub { m/$regex/ }, $what | VISIT_STOP_FIRST_MATCH);
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
normalized (by L</unparse>).

=item VISIT_OR_CLAUSE_FULL

CODE will be passed the full OR clauses of this relation.  The clauses
will be normalized (by L</unparse>)

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
    my ($self, $code, $flags, $partial) = @_;
    my $relation = $partial // $self;
    $flags //= 0;
    if ($relation->[0] eq 'PRED') {
        my $against = $relation->[1];
        $against = $self->unparse ($relation) if $flags & VISIT_PRED_FULL;
        local $_ = $against;
        return $code->($against);
    } elsif (($flags & VISIT_OR_CLAUSE_FULL) == VISIT_OR_CLAUSE_FULL and
             $relation->[0] eq 'OR') {
        my $against = $self->unparse ($relation);
        local $_ = $against;
        return $code->($against);
    } elsif ($relation->[0] eq 'AND' or $relation->[0] eq 'OR' or
             $relation->[0] eq 'NOT') {
        for my $rel (@$relation[1 .. $#$relation]) {
            my $ret = $self->visit ($code, $flags, $rel);
            if ($ret && ($flags & VISIT_STOP_FIRST_MATCH)) {
                return $ret;
            }
        }
        return;
    }
}

=item empty ()

Returns a truth value if this relation is empty (i.e. it contains no
predicates).

=cut

sub empty {
    my ($self) = @_;
    return 1 if $self->[0] eq 'AND' and not $self->[1];
    return 0;
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
