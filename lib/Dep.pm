# -*- perl -*-

# This library handles operations on dependencies.
# It provides a routine Dep::parse that converts a dependency line in
# the dpkg control format to its own internal format.
# All its other routines work on that internal format.

# A dependency line is viewed as a predicate formula.  The comma
# separator means "and", and the alternatives separator means "or".
# A bare package name is the predicate "a package of this name is
# available".  A package name with a version clause is the predicate
# "a package of this name that satisfies this version clause is
# available".
#
# This way, the presence of a package can be represented simply as
# "packagename (=version)", or if it has a Provides line, as
# "packagename (=version) | provide1 | provide2 | provide3".

use strict;

use lib "$ENV{'LINTIAN_ROOT'}/lib";
use Pipeline;

package Dep;

# ---------------------------------
# public routines

sub Pred {
    $_[0] =~ 
	    /^\s*                           # skip leading whitespace
	      ([a-zA-Z0-9][a-zA-Z0-9+.-]+)  # package name
	      (?:                           # start of optional part
  	        \s* \(                      # open parenthesis for version part
                \s* (<<|<=|=|>=|>>|<|>)     # relation part
                \s* (.*?)                   # do not attempt to parse version
                \s* \)                      # closing parenthesis
	      )?                            # end of optional part
              (?:                           # start of optional architecture
                \s* \[                      # open bracket for architecture
                \s* (.*?)                   # don't parse architectures now
                \s* \]                      # closing bracket
              )?                            # end of optional architecture
	    /x;
    return ['PRED', $1, undef, undef, $4] if not defined $2;
    my $two = $2;
    if ($two eq '<') {
	$two = '<<';
    } elsif ($two eq '>') {
	$two = '>>';
    }
    return ['PRED', $1, $two, $3, $4];
}

sub Or { return ['OR', @_]; }
sub And { return ['AND', @_]; }
sub Not { return ['NOT', $_[0]]; }

# Convert a dependency line into the internal format.
# Non-local callers may store the results of this routine.
sub parse 
{	my @deps;
    for (split(/\s*,\s*/, $_[0])) 
	{ 	my @alts;

		if ( $_ =~ /^perl\s+\|\s+perl5$/ or $_ =~ /^perl5\s+\|\s+perl\s+/ )
			{ $_ = "perl5"; }
		for (split(/\s*\|\s*/, $_)) { push(@alts, Dep::Pred($_)); }
		if (@alts == 1) { push(@deps, $alts[0]); } 
		else { push(@deps, ['OR', @alts]); }
    }
    return $deps[0] if @deps == 1;
    return ['AND', @deps];
}

# ---------------------------------

# Takes two predicate formulas and returns true iff the second can be
# deduced from the first.
sub implies {
    my ($p, $q) = @_;
    my $i;

    #Dep::debugprint($p);
    #warn " |- ";
    #Dep::debugprint($q);
    #warn "\n";
    #use Data::Dumper;

    if ($q->[0] eq 'PRED') {
	## N.B. AND and OR here do the same thing!!!
	if ($p->[0] eq 'PRED') {
	  	return Dep::pred_implies($p, $q);
	} elsif ($p->[0] eq 'AND') {
	    $i = 1;
	    while ($i < @$p) {
		return 1 if Dep::implies($p->[$i++], $q);
	    }
	    return 0;
 	} elsif ($p->[0] eq 'OR') {
	    $i = 1;
	    while ($i < @$p) {
		return 0 if not Dep::implies($p->[$i++], $q);
	    }
	    return 1;
	} elsif ($p->[0] eq 'NOT') {
	    return Dep::implies_inverse($p->[1], $q);
	}
    } elsif ($q->[0] eq 'AND') {
	# Each of q's clauses must be deduced from p.
	$i = 1;
	while ($i < @$q) {
	    return 0 if not Dep::implies($p, $q->[$i++]);
	}
	return 1;
    } elsif ($q->[0] eq 'OR') {
	# Any of q's clauses may be deduced from p.  This isn't entirely
	# sufficient and will not correctly deduce that "a|b" implies "a|b|c".
	# I don't see how to get that right using this code structure, or any
	# simple change that would get it right.
	$i = 1;
	while ($i < @$q) {
	    return 1 if Dep::implies($p, $q->[$i++]);
	}
	return 0;
    } elsif ($q->[0] eq 'NOT') {
	if ($p->[0] eq 'NOT') {
	    return Dep::implies($q->[1], $p->[1]);
	}
	return Dep::implies_inverse($p, $q->[1]);
    }
}

# Takes two predicate formulas and returns true iff the falsehood of
# the second can be deduced from the truth of the first.
sub implies_inverse {
    my ($p, $q) = @_;
    my $i;

#    Dep::debugprint($p);
#    warn " |- !";
#    Dep::debugprint($q);
#    warn "\n";

    if ($$q[0] eq 'PRED') {
	if ($$p[0] eq 'PRED') {
	    return Dep::pred_implies_inverse($p, $q);
	} elsif ($$p[0] eq 'AND') {
	    # q's falsehood can be deduced from any of p's clauses
	    $i = 1;
	    while ($i < @$p) {
		return 1 if Dep::implies_inverse($$p[$i++], $q);
	    }
	    return 0;
	} elsif ($$p[0] eq 'OR') {
	    # q's falsehood must be deduced from each of p's clauses
	    $i = 1;
	    while ($i < @$p) {
		return 0 if not Dep::implies_inverse($$p[$i++], $q);
	    }
	    return 1;
	} elsif ($$p[0] eq 'NOT') {
	    return Dep::implies($q, $$p[1]);
	}
    } elsif ($$q[0] eq 'AND') {
	# Any of q's clauses must be falsified by p.
	$i = 1;
	while ($i < @$q) {
	    return 1 if Dep::implies_inverse($p, $$q[$i++]);
	}
	return 0;
    } elsif ($$q[0] eq 'OR') {
	# Each of q's clauses must be falsified by p.
	$i = 1;
	while ($i < @$q) {
	    return 0 if not Dep::implies_inverse($p, $$q[$i++]);
	}
	return 1;
    } elsif ($$q[0] eq 'NOT') {
	return Dep::implies($p, $$q[1]);
    }
}

# Takes two predicates and returns true iff the second can be deduced
# from the first.
sub pred_implies {
    my ($p, $q) = @_;
    # If the names don't match, there is no relationship between them.
    return undef if $$p[1] ne $$q[1];

    # If the names match, then the only difference is in the architecture or
    # version clauses.  First, check architecture.  The architectures for p
    # must be a superset of the architectures for q.
    my @p_arches = split(' ', $$p[4] || '');
    my @q_arches = split(' ', $$q[4] || '');
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
            return undef;
        }

        # Both have arches.  If neither are negated, we know nothing useful
        # unless q is a subset of p.
        elsif (not $p_arch_neg and not $q_arch_neg) {
            my %p_arches = map { $_ => 1 } @p_arches;
            my $subset = 1;
            for my $arch (@q_arches) {
                $subset = 0 unless $p_arches{$arch};
            }
            return undef unless $subset;
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
            return undef unless $subset;
        }

        # If q is negated and p isn't, we'd need to know the full list of
        # arches to know if there's any relationship, so bail.
        elsif (not $p_arch_neg and $q_arch_neg) {
            return undef;
        }

        # If p is negated and q isn't, q is a subset of p iff none of the
        # negated arches in p are present in q.
        elsif ($p_arch_neg and not $q_arch_neg) {
            my %q_arches = map { $_ => 1 } @q_arches;
            my $subset = 1;
            for my $arch (@p_arches) {
                $subset = 0 if $q_arches{substr($arch, 1)};
            }
            return undef unless $subset;
        }
    }

    # Now, down to version.  The implication is true if p's clause is stronger
    # than q's, or is equivalent.

    # If q has no version clause, then p's clause is always stronger.
    return 1 if not defined $$q[2];

    # If q does have a version clause, then p must also have one.
    return 0 if not defined $$p[2];

    if ($$q[2] eq '=') {
	# q wants an exact version, so p must provide that exact version.
	return ($$p[2] eq '=' and Dep::versions_equal($$p[3], $$q[3]));
    }

    if ($$q[2] eq '<=') {
	# A 'greater than' clause implies nothing about a 'lesser than'.
	return undef if $$p[2] eq '>>' or $$p[2] eq '>=';
	# If p's clause is << or <= or =, the version involved must be <= q's.
	return Dep::versions_lte($$p[3], $$q[3]);
    }

    if ($$q[2] eq '<<') {
	return undef if $$p[2] eq '>>' or $$p[2] eq '>=';
	return Dep::versions_lte($$p[3], $$q[3]) if $$p[2] eq '<<';
	return Dep::versions_lt($$p[3], $$q[3]);
    }

    if ($$q[2] eq '>=') {
	return undef if $$p[2] eq '<<' or $$p[2] eq '<=';
	return Dep::versions_gte($$p[3], $$q[3]);
    }

    if ($$q[2] eq '>>') {
	return undef if $$p[2] eq '<<' or $$p[2] eq '<=';
	return Dep::versions_gte($$p[3], $$q[3]) if $$p[2] eq '>>';
	return Dep::versions_gt($$p[3], $$q[3]);
    }

    return undef;
}

# Takes two predicates and returns true iff the falsehood of the second
# can be deduced from the truth of the first.
sub pred_implies_inverse {
    my ($p, $q) = @_;
    my $res = Dep::pred_implies($q, $p);

    return not $res if defined $res;
    return undef;
}

# ---------------------------------
# version routines

my %cached;

sub versions_equal {
    my ($p, $q) = @_;
    my $res;

    return 1 if $p eq $q;
    return 1 if $Dep::cached{"$p == $q"};
    return 1 if $Dep::cached{"$p <= $q"} and $Dep::cached{"$p >= $q"};
    return 0 if $Dep::cached{"$p != $q"};
    return 0 if $Dep::cached{"$p << $q"};
    return 0 if $Dep::cached{"$p >> $q"};

    $res = Dep::get_version_cmp($p, 'eq', $q);

    if ($res) {
	$Dep::cached{"$p == $q"} = 1;
    } else {
	$Dep::cached{"$p != $q"} = 1;
    }

    return $res;
}

sub versions_lte {
    my ($p, $q) = @_;
    my $res;

    return 1 if $p eq $q;
    return 1 if $Dep::cached{"$p <= $q"};
    return 1 if $Dep::cached{"$p == $q"};
    return 1 if $Dep::cached{"$p << $q"};
    return 0 if $Dep::cached{"$p >> $q"};
    return 0 if $Dep::cached{"$p >= $q"} and $Dep::cached{"$p != $q"};

    $res = Dep::get_version_cmp($p, 'le', $q);

    if ($res) {
	$Dep::cached{"$p <= $q"} = 1;
    } else {
	$Dep::cached{"$p >> $q"} = 1;
    }

    return $res;
}

sub versions_gte {
    my ($p, $q) = @_;
    my $res;

    return 1 if $p eq $q;
    return 1 if $Dep::cached{"$p >= $q"};
    return 1 if $Dep::cached{"$p == $q"};
    return 1 if $Dep::cached{"$p >> $q"};
    return 0 if $Dep::cached{"$p << $q"};
    return 0 if $Dep::cached{"$p <= $q"} and $Dep::cached{"$p != $q"};

    $res = Dep::get_version_cmp($p, 'ge', $q);

    if ($res) {
	$Dep::cached{"$p >= $q"} = 1;
    } else {
	$Dep::cached{"$p << $q"} = 1;
    }

    return $res;
}

sub versions_lt {
    my ($p, $q) = @_;
    my $res;

    return 0 if $p eq $q;
    return 1 if $Dep::cached{"$p << $q"};
    return 0 if $Dep::cached{"$p == $q"};
    return 0 if $Dep::cached{"$p >= $q"};
    return 0 if $Dep::cached{"$p >> $q"};
    return 1 if $Dep::cached{"$p <= $q"} and $Dep::cached{"$p != $q"};

    $res = Dep::get_version_cmp($p, 'lt', $q);

    if ($res) {
	$Dep::cached{"$p << $q"} = 1;
    } else {
	$Dep::cached{"$p >= $q"} = 1;
    }

    return $res;
}

sub versions_gt {
    my ($p, $q) = @_;
    my $res;

    return 0 if $p eq $q;
    return 1 if $Dep::cached{"$p >> $q"};
    return 0 if $Dep::cached{"$p == $q"};
    return 0 if $Dep::cached{"$p <= $q"};
    return 0 if $Dep::cached{"$p << $q"};
    return 1 if $Dep::cached{"$p >= $q"} and $Dep::cached{"$p != $q"};

    $res = Dep::get_version_cmp($p, 'gt', $q);

    if ($res) {
	$Dep::cached{"$p >> $q"} = 1;
    } else {
	$Dep::cached{"$p <= $q"} = 1;
    }

    return $res;
}

sub get_version_cmp {
    return ::spawn('dpkg', '--compare-versions', @_) == 0;
}

sub get_dups {
    my $relation = shift;

    if ($relation->[0] ne 'AND') {
	return ();
    }

    shift @$relation;
    my %seen;
    foreach my $i (@$relation) {
	next if ($i->[0] eq 'OR');  #assume OR is always ok
	$seen{$i->[1]}++;
    }
    return grep {$seen{$_} > 1} keys(%seen);
}

# ---------------------------------

sub debugprint {
    my $x;
    my $i;

    for $x (@_) {
	if ($$x[0] eq 'PRED') {
	    if (@$x == 2) {
		warn "PRED($$x[1])";
	    } else {
 		warn "PRED($$x[1] $$x[2] $$x[3])";
 	    }
 	} else {
 	    warn "$$x[0](";
 	    $i = 1;
 	    while ($i < @$x) {
 	        Dep::debugprint($$x[$i++]);
 		warn ", " if ($i < @$x);
 	    }
 	    warn ")";
 	}
     }
}

1;
