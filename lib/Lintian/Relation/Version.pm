# -*- perl -*-
# Lintian::Relation::Version -- comparison operators on Debian versions

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

package Lintian::Relation::Version;

use strict;
use warnings;

use Carp qw(croak);

use Lintian::Command qw(spawn);

use base 'Exporter';
BEGIN {
    our @EXPORT = qw(versions_equal versions_lte versions_gte versions_lt
                     versions_gt versions_compare);
}

# We save a cache of every version comparison we've done so that we don't have
# to fork dpkg again if the same comparison comes up.
our %CACHE;

=head1 NAME

Lintian::Relation::Version - Comparison operators on Debian versions

=head1 SYNOPSIS

    print "yes\n" if versions_equal('1.0', '1.00');
    print "yes\n" if versions_gte('1.1', '1.0');
    print "no\n" if versions_lte('1.1', '1.0');
    print "yes\n" if versions_gt('1.1', '1.0');
    print "no\n" if versions_lt('1.1', '1.1');
    print "yes\n" if versions_compare('1.1', '<=', '1.1');

=head1 DESCRIPTION

This module provides five functions for comparing version numbers.  The
underlying implementation uses C<dpkg --compare-versions> to ensure that
the results match what dpkg will expect.  All comparisons are cached so
that we do not fork B<dpkg> again if we see the same comparison.

=head1 FUNCTIONS

=over 4

=item versions_equal(A, B)

Returns true if A is equal to B (C<=>) and false otherwise.

=cut

sub versions_equal {
    my ($p, $q) = @_;
    my $result;

    return 1 if $p eq $q;
    return 1 if $CACHE{"$p == $q"};
    return 1 if $CACHE{"$p <= $q"} and $CACHE{"$p >= $q"};
    return 0 if $CACHE{"$p != $q"};
    return 0 if $CACHE{"$p << $q"};
    return 0 if $CACHE{"$p >> $q"};

    $result = compare($p, 'eq', $q);

    if ($result) {
        $CACHE{"$p == $q"} = 1;
    } else {
        $CACHE{"$p != $q"} = 1;
    }

    return $result;
}

=item versions_lte(A, B)

Returns true if A is less than or equal (C<< <= >>) to B and false
otherwise.

=cut

sub versions_lte {
    my ($p, $q) = @_;
    my $result;

    return 1 if $p eq $q;
    return 1 if $CACHE{"$p <= $q"};
    return 1 if $CACHE{"$p == $q"};
    return 1 if $CACHE{"$p << $q"};
    return 0 if $CACHE{"$p >> $q"};
    return 0 if $CACHE{"$p >= $q"} and $CACHE{"$p != $q"};

    $result = compare($p, 'le', $q);

    if ($result) {
        $CACHE{"$p <= $q"} = 1;
    } else {
        $CACHE{"$p >> $q"} = 1;
    }

    return $result;
}

=item versions_gte(A, B)

Returns true if A is greater than or equal (C<< >= >>) to B and false
otherwise.

=cut

sub versions_gte {
    my ($p, $q) = @_;
    my $result;

    return 1 if $p eq $q;
    return 1 if $CACHE{"$p >= $q"};
    return 1 if $CACHE{"$p == $q"};
    return 1 if $CACHE{"$p >> $q"};
    return 0 if $CACHE{"$p << $q"};
    return 0 if $CACHE{"$p <= $q"} and $CACHE{"$p != $q"};

    $result = compare($p, 'ge', $q);

    if ($result) {
        $CACHE{"$p >= $q"} = 1;
    } else {
        $CACHE{"$p << $q"} = 1;
    }

    return $result;
}

=item versions_lt(A, B)

Returns true if A is less than (C<<< << >>>) B and false otherwise.

=cut

sub versions_lt {
    my ($p, $q) = @_;
    my $result;

    return 0 if $p eq $q;
    return 1 if $CACHE{"$p << $q"};
    return 0 if $CACHE{"$p == $q"};
    return 0 if $CACHE{"$p >= $q"};
    return 0 if $CACHE{"$p >> $q"};
    return 1 if $CACHE{"$p <= $q"} and $CACHE{"$p != $q"};

    $result = compare($p, 'lt', $q);

    if ($result) {
        $CACHE{"$p << $q"} = 1;
    } else {
        $CACHE{"$p >= $q"} = 1;
    }

    return $result;
}

=item versions_gt(A, B)

Returns true if A is greater than (C<<< >> >>>) B and false otherwise.

=cut

sub versions_gt {
    my ($p, $q) = @_;
    my $result;

    return 0 if $p eq $q;
    return 1 if $CACHE{"$p >> $q"};
    return 0 if $CACHE{"$p == $q"};
    return 0 if $CACHE{"$p <= $q"};
    return 0 if $CACHE{"$p << $q"};
    return 1 if $CACHE{"$p >= $q"} and $CACHE{"$p != $q"};

    $result = compare($p, 'gt', $q);

    if ($result) {
        $CACHE{"$p >> $q"} = 1;
    } else {
        $CACHE{"$p <= $q"} = 1;
    }

    return $result;
}

=item versions_compare(A, OP, B)

Returns true if A OP B, where OP is one of C<=>, C<< <= >>, C<< >= >>,
C<<< << >>>, or C<<< >> >>>, and false otherwise.

=cut

sub versions_compare {
    my ($p, $op, $q) = @_;
    if    ($op eq  '=') { return versions_equal($p, $q) }
    elsif ($op eq '<=') { return versions_lte  ($p, $q) }
    elsif ($op eq '>=') { return versions_gte  ($p, $q) }
    elsif ($op eq '<<') { return versions_lt   ($p, $q) }
    elsif ($op eq '>>') { return versions_gt   ($p, $q) }
    else { croak("unknown operator $op") }
}

# The internal function used to do the comparisons.
sub compare {
    return spawn(undef, ['dpkg', '--compare-versions', @_]);
}

=back

=head1 NOTES

This module can probably be dropped once Dpkg::Version is available on the
host where lintian.debian.org is generated.  Using Dpkg::Version directly
will be much more efficient.

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
# vim: syntax=perl sw=4 sts=4 ts=4 et shiftround
