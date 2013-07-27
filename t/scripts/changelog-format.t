#!/usr/bin/perl -w

# Copyright (C) 2011 Raphael Geissert <geissert@debian.org>
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

use Test::More;
use Parse::DebianChangelog;

my $changelog = Parse::DebianChangelog->init({ infile => 'debian/changelog' })
		or BAIL_OUT('fatal error while loading parser');

plan skip_all => 'Only valid for regular Debian releases'
    if should_skip($changelog);
my $changes = $changelog->dpkg()->{'Changes'};
my $line = 0;
my $prev_head = '';
my $release_header = 0;
my $is_release = 1;
$is_release = 0 if $changelog->dpkg->{'Distribution'} eq 'UNRELEASED';

foreach (split /\n/,$changes) {
    # Parse::DebianChangelog adds an empty line at the beginning:
    next if ($_ eq '');

    # P::DC adds a space too:
    s/^ //;
    $line++;

    if (m/^\s*$/o) {
        $release_header = 0;
        next;
    }

    # Ignore the reminder to generate the tag summary
    if ($line < 10 && m/XXX: generate tag summary/) {
        ok(!$is_release, "No TODO-marker in changelog for tag summary!")
            or diag("Generate it with private/generate-tag-summary");
        next;
    }

    my $spaces = 0;
    $spaces++ while (s/^\s//);

    cmp_ok (($spaces + length), '<=', 75, "Changelog line is not too long: line $line");

=meh
    # Disabled because Parse::DebianChangelog trims lines for us
    ok ($_ eq '' || m/[^\s]$/, 'No trailing space at the end of line')
	or diag("line: $line");
    s/\s*$//;
=cut

    if ($spaces == 2) {
	if (m/^\*/) {
	    pass('line is a bullet list item');
	    ok(m/:$/, 'bullet item ends in colon')
		or diag("line: $line");
	} elsif ($line == 3) {
	    ok(m/^[A-Z\"]/, 'line is the release header')
		or diag("line: $line");
            $release_header = 1;
	} else {
            # Unless this is a multi-line release header, it should
            # have been a bullet list.  Also limit the length of the
            # release header.
            unless ($release_header && $line < 7) {
                fail('line is a bullet list item');
                diag("line: $line");
            }
	}
    } elsif ($spaces == 4) {
	ok(m/^\+/, 'line is a sub-item of a bullet-list item')
	    or diag("line: $line");
    } elsif ($spaces == 6) {
	if ($prev_head eq '+') {
	    ok(m/^[^+*]/, 'line is a continuation of change description')
		or diag("line: $line");
	} else {
	    ok(m/^-/, 'line is a sub-item of tags summary')
		or diag("line: $line");
	}
    } elsif ($spaces == 8) {
	ok($prev_head eq '-', 'line is a continuation of tag change')
	    or diag("line: $line");
    } else {
	ok(m/^(:?\.|lintian.+)$/, 'line is an entry header')
	    or diag("line: $line");
    }

    if (m/\S\w\. (.)/) {
	ok($1 eq ' ', 'two spaces after a full stop')
	    or diag("line: $line");
    }

    if (m/^([*+-])/) {
        $prev_head = $1;
    }

}

done_testing();

sub should_skip{
    my ($changelog) = @_;
    my $version = $changelog->dpkg->{'Version'};
    # Normal releases look something like X.Y.Z or X.Y.Z~rcR
    return $version !~ m/^\d+(?:\.\d+)*(?:\~rc\d+)?$/o;
}

