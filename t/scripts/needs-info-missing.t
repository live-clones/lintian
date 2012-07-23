#!/usr/bin/perl

# Copyright (C) 2009 by Raphael Geissert <atomo64@gmail.com>
# Copyright (C) 2009 Russ Allbery <rra@debian.org>
#
# This file is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.

use strict;

use Test::More;
use Lintian::Util qw(read_dpkg_control slurp_entire_file);

# Find all of the desc files in checks.  We'll do one check per description.
our @DESCS = (<$ENV{LINTIAN_ROOT}/checks/*.desc>,
              <$ENV{LINTIAN_ROOT}/collection/*.desc>);
our @MODULES = (<$ENV{LINTIAN_ROOT}/lib/Lintian/Collect.pm>,
		<$ENV{LINTIAN_ROOT}/lib/Lintian/Collect/*.pm>);

plan tests => scalar(@DESCS)+scalar(@MODULES);

# Maps a sub to a Disjunctive Normal Form (DNF) of dependencies
#  e.g. "changelog-file,:field or debfiles,:field"
# As it is a DNF, it is read as
#  "(changelog-file AND :field) OR (debfiles AND :field)".
#
# ":X" is a symbol dependency used in L::Collect{,::*}.  It is useful
# to declare an "indirect" dependency, so methods using (e.g.) the
# "field" sub does not need to know what it depends on.
my %needs_info;

# Build the Needs-Info hash from the Collect modules
for my $module (@MODULES) {
    my $pretty_module = $module;
    $pretty_module =~ s,^\Q$ENV{LINTIAN_ROOT}/lib/,,;
    open(PM, '<', $module) or die("Could not open module $pretty_module");
    my (%seen_subs, %seen_needsinfo, @errors, @warnings);
    while (<PM>) {
	if (m/^\s*sub\s+(\w+)/) {
	    $seen_subs{$1} = 1;
	}
	if (m/^\s*\#\s*sub\s+(\w+)\s+Needs-Info\s+(.*)$/) {
	    my ($sub, $all_info) = ($1, $2);
	    $seen_needsinfo{$sub} = 1;
	    $all_info =~ s/\s//g;
	    $all_info =~ s/,,/,/g;
	    if (!$all_info) {
		push @errors, "$sub has empty needs-info\n";
		next;
	    }
	    $all_info =~ s/^<>$//;
	    if (exists($needs_info{$sub})) {
		if ($all_info ne $needs_info{$sub}) {
		    $needs_info{$sub} .= " or $all_info";
		}
	    } else {
		$needs_info{$sub} = $all_info;
	    }
	}
    }
    close(PM);
    if (scalar(@errors)) {
	ok(0, "$pretty_module has per-method needs-info") or diag(@errors);
	diag("\n", @warnings) if (@warnings);
	next;
    }
    for my $sub (keys %seen_subs) {
	if (exists($seen_needsinfo{$sub})) {
	    delete $seen_needsinfo{$sub};
	    delete $seen_subs{$sub};
	}
    }

    delete $seen_subs{'new'};

    is(scalar(keys(%seen_subs)) + scalar(keys(%seen_needsinfo)), 0,
	"$pretty_module has per-method needs-info") or
	diag("Subs missing info: ", join(', ', keys(%seen_subs)), "\n",
	     "Info for unknown subs: ", join(', ', keys(%seen_needsinfo)),"\n");

    diag("\n", @warnings) if @warnings;
}

for my $desc (@DESCS) {
    my ($header) = read_dpkg_control($desc);
    my %needs = map { $_ => 1 } split(/\s*,\s*/, $header->{'needs-info'} || '');

    if ($desc =~ m/lintian\.desc$/) {
	pass("lintian.desc has all required needs-info for Lintian::Collect");
	next;
    }

    my ($check) = split(/\.desc$/, $desc);
    my $code =slurp_entire_file($check);
    my %subs;
    while ($code =~ s/\$info\s*->\s*(\w+)//) {
	$subs{$1} = 1;
    }

    my @warnings;
    my $missing = 0;

    for my $sub (keys %subs) {
	if (exists($needs_info{$sub})) {
            my @miss = find_missing (\%needs, $needs_info{$sub});
            if (@miss) {
                $missing++;
                foreach my $needed (@miss) {
                    push @warnings, "$sub needs $needed\n";
                }
	    }
	} else {
	    push @warnings, "Unknown method \$info->$sub\n";
	}
    }

    my $short = $desc;
    $short =~ s,^\Q$ENV{LINTIAN_ROOT}/,,;
    $short =~ s,^collection/,coll/,;
    is($missing, 0, "$short has all required needs-info for Lintian::Collect") or
	diag(@warnings);
}

sub find_missing {
    my ($declared, $depends) = @_;
    my @missing = ();
    my @unchecked = ($depends);
    # Each $depline has the format "X,Y or Z", which is read as
    # "(X and Y) or Z".  This is also known as "Disjunctive Normal Form"
    # (without negation).
    while (my $depline = pop @unchecked) {
        my @orlist = split m/\s+or\s+/o, $depline;
        my $ok = 0;
      ORDEP:
        foreach my $ordep (@orlist) {
            my @deps = split m/\s+,\s+/o, $ordep;
            while (my $dep = pop @deps) {
                # symbolic dependency ?
                if ($dep =~ s/^://) {
                    # Handle with recursion
                    if (find_missing ($declared, $needs_info{$dep})) {
                        # cannot satisfy this part of the relation
                        next ORDEP;
                    }
                    next;
                }
                # ... "normal" dependency
                unless (exists $declared->{$dep}) {
                    # cannot satisfy this part of the relation
                    next ORDEP;
                }
            }
            $ok = 1;
            last;
        }
        if (not $ok) {
            push @missing, $depline;
        }
    }
    return @missing;
}
