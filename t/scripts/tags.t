#!/usr/bin/perl

# Copyright (C) 1998 Richard Braakman
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

use strict;
use warnings;

use Test::More qw(no_plan);

use Lintian::Check qw(check_spelling);
use Lintian::Data;
use Lintian::Profile;
use Lintian::Tags ();
use Lintian::Util qw(read_dpkg_control);

my $vendor = Lintian::Profile->new ('debian/main',
                                 [$ENV{'LINTIAN_ROOT'}]);
my @DESCS = <$ENV{'LINTIAN_ROOT'}/checks/*.desc>;

my %severities = map { $_ => 1 } 'pedantic', @Lintian::Tags::SEVERITIES;
my %certainties = map { $_ => 1 } @Lintian::Tags::CERTAINTIES;

Lintian::Data->set_vendor ($vendor);

for my $desc_file (@DESCS) {
    for my $i (read_dpkg_control($desc_file)) {
	$desc_file =~ s#.*/##;
	if (exists $i->{'tag'}) {
	    ok($i->{'tag'} =~ /^[\w0-9.+-]+$/, "Tag has valid characters")
		or diag("$desc_file: $i->{'tag'}\n");
	    ok(exists $i->{'info'}, "Tag has info")
		or diag("$desc_file: $i->{'tag'}\n");
	    cmp_ok(length($i->{'tag'}), '<=', 68, "Tag is not too long")
		or diag("$desc_file: $i->{'tag'}\n");

	    my $info = $i->{'info'} || '';

	    is(check_spelling(undef, $info), 0,
		"$desc_file: $i->{'tag'} has no spelling errors");

	    # Check the tag info for unescaped <> or for unknown tags (which
	    # probably indicate the same thing).
	    my @tags;
	    while ($info =~ s,<([^\s>]+)(?:\s+href=\"[^\"]+\")?>.*?</\1>,,s) {
		push (@tags, $1);
	    }
	    my %known = map { $_ => 1 } qw(a em i tt);
            my %seen;
	    @tags = grep { !$known{$_} && !$seen{$_}++ } @tags;
	    is(join(', ', @tags), '', 'Tag info has unknown html tags')
		or diag("$desc_file: $i->{'tag'}\n");

	    ok($info !~ /[<>]/, "Tag info has no stray angle brackets")
		or diag("$desc_file: $i->{'tag'}\n");

	    my $severity = $i->{'severity'};
	    my $certainty = $i->{'certainty'};
	    ok(!$severity || exists $severities{$severity}, "Tag has valid severity")
		or diag("$desc_file: $i->{'tag'} severity: $severity\n");
	    ok(!$certainty || exists $certainties{$certainty}, "Tag has valid certainty")
		or diag("$desc_file: $i->{'tag'} certainty: $certainty\n");
	    ok($severity, "Tag has severity")
		or diag("$desc_file: $i->{'tag'}");
	    ok($certainty, "Tag has certainty")
		or diag("$desc_file: $i->{'tag'}");
	}
    }
}
