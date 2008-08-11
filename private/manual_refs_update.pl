#!/usr/bin/perl -w

# Copyright © 2001 Colin Watson
# Copyright © 2008 Jordà Polo
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

# Invoke as ./manual_refs_update.pl > manual_refs.new
# You need copies of all the relevant manuals installed in the standard
# places locally.

use strict;
use warnings;

# For each manual, we need:
#  * Location of the manual directory on the local filesystem
#  * Base URL for the eventual target of the reference
#  * Regex to match the title
#  * Regex to match the possible references
#  * Mapping from regex fields to reference fields

my $ddoc_title = qr/<title>(.+?)<\/title>/;
my $ddoc_ref = qr/<a href="(.+?)">([A-Z]|[A-Z]?[\d\.]+?)\.?\s+([\w\s[:punct:]]+?)<\/a>/;
my $ddoc_fields = [ [ 'url' ], [ 'section' ], [ 'title' ] ];

my %manuals = (
    'policy' => [ '/usr/share/doc/debian-policy/policy.html/index.html',
                  'http://www.debian.org/doc/debian-policy/',
                  $ddoc_title, $ddoc_ref, $ddoc_fields ],
    'devref' => [ '/usr/share/doc/developers-reference/index.html',
                  'http://www.debian.org/doc/developers-reference/',
                  $ddoc_title, $ddoc_ref, $ddoc_fields ],
    'menu'   => [ '/usr/share/doc/menu/html/index.html',
                  'http://www.debian.org/doc/packaging-manuals/menu.html/',
                  $ddoc_title, $ddoc_ref, $ddoc_fields ],
    'fhs'    => [ '/usr/share/doc/debian-policy/fhs/fhs-2.3.html',
                  'http://www.pathname.com/fhs/pub/fhs-2.3.html',
                  qr/<title\s*>(.+?)<\/title\s*>/i,
                  qr/<a\s*href="(#.+?)"\s*>([\w\s[:punct:]]+?)<\/a\s*>/i,
                  [ [ 'section', 'url' ], [ 'title' ] ] ],
);

# Collect all possible references from available manuals.

for my $manual (keys %manuals) {
    my ($index, $url, $title_re, $ref_re, $fields) = @{$manuals{$manual}};
    my $title = 0;

    unless (-f $index) {
        print STDERR "Manual '$manual' not installed; not updating.\n";
        next;
    }

    open(INDEX, "$index") or die "Couldn't open $index: $!";

    # Read until there are 2 newlines. This hack is needed since some lines in
    # the Developer's Reference are cut in the middle of <a>...</a>.
    local $/ = "\n\n";

    while (<INDEX>) {
        if (not $title and m/$title_re/) {
            $title = 1;
            my @out = ( $manual, '', $1, $url );
            print join('::', @out) . "\n";
        }

        while (m/$ref_re/g) {
            my %ref;
            for(my $i = 0; $i < scalar @{$fields}; $i++) {
                foreach my $c (@{$fields->[$i]}) {
                    my $v = $i + 1;
                    $ref{$c} = eval '$' . $v;
                }
            }

            $ref{section} =~ s/^\#(.+)$/\L$1/;
            $ref{title} =~ s/\n//g;
            $ref{url} = "$url$ref{url}";
            my @out = ( $manual, $ref{section}, $ref{title}, $ref{url} );
            print join('::', @out) . "\n";
        }
    }

    close(INDEX);
}

# vim: sw=4 sts=4 ts=4 et sr
