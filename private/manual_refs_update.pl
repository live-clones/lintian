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
#  * Base URL for the eventual target of the reference (or empty string if no
#    public URL is available)
#  * Regex to match the possible references
#  * Mapping from regex fields to reference fields (array of arrays of
#    keywords: url, section title; the position of each keyword in the array
#    defines which is its corresponding group in the regex)

my $title_re = qr/<title\s?>(.+?)<\/title\s?>/i;
my $link_re = qr/<link href="(.+?)" rel="[\w]+" title="([A-Z]|[A-Z]?[\d\.]+?)\.?\s+([\w\s[:punct:]]+?)">/;
my $index_re = qr/<a href="(.+?)">([A-Z]|[A-Z]?[\d\.]+?)\.?\s+([\w\s[:punct:]]+?)<\/a>/;
my $fields = [ [ 'url' ], [ 'section' ], [ 'title' ] ];

my %manuals = (
    'policy' => [
        '/usr/share/doc/debian-policy/policy.html/index.html',
        'http://www.debian.org/doc/debian-policy/',
        $link_re, $fields
    ],
    'menu-policy' => [
        '/usr/share/doc/debian-policy/menu-policy.html/index.html',
        'http://www.debian.org/doc/packaging-manuals/menu-policy/',
        $link_re, $fields
    ],
    'perl-policy' => [
        '/usr/share/doc/debian-policy/perl-policy.html/index.html',
        'http://www.debian.org/doc/packaging-manuals/perl-policy/',
        $link_re, $fields
    ],
    'python-policy' => [
        '/usr/share/doc/python/python-policy.html/index.html',
        'http://www.debian.org/doc/packaging-manuals/python-policy/',
        $link_re, $fields
    ],
    'lintian' => [
        '/usr/share/doc/lintian/lintian.html/index.html',
        'http://lintian.debian.org/manual/',
        $link_re, $fields
    ],
    'devref' => [
        '/usr/share/doc/developers-reference/index.html',
        'http://www.debian.org/doc/developers-reference/',
        $index_re, $fields
    ],
    'menu' => [
        '/usr/share/doc/menu/html/index.html',
        'http://www.debian.org/doc/packaging-manuals/menu.html/',
        $index_re, $fields
    ],
    'doc-base' => [
        '/usr/share/doc/doc-base/doc-base.html/index.html', '',
        $index_re, $fields
    ],
    'debconf-spec' => [
        '/usr/share/doc/debian-policy/debconf_specification.html',
        'http://www.debian.org/doc/packaging-manuals/debconf_specification.html',
        qr/<a href="(#.+?)">([\w\s[:punct:]]+?)<\/a>/,
        [ [ 'section', 'url' ], [ 'title' ] ]
    ],
    # Extract chapters only, since the HTML available in netfort.gr.jp isn't
    # exactly the same with regards to section IDs as the version included in
    # the package.
    'libpkg-guide' => [
        '/usr/share/doc/libpkg-guide/libpkg-guide.html',
        'http://www.netfort.gr.jp/~dancer/column/libpkg-guide/libpkg-guide.html',
        qr/class="chapter"><a href="(.+?)">([\d\.]+?)\.? ([\w\s[:punct:]]+?)<\/a>/,
        $fields
    ],
    'fhs' => [
        '/usr/share/doc/debian-policy/fhs/fhs-2.3.html',
        'http://www.pathname.com/fhs/pub/fhs-2.3.html',
        qr/<a\s*href="(#.+?)"\s*>([\w\s[:punct:]]+?)<\/a\s*>/i,
        [ [ 'section', 'url' ], [ 'title' ] ]
    ],
);

# Collect all possible references from available manuals.

for my $manual (sort keys %manuals) {
    my ($index, $url, $ref_re, $fields) = @{$manuals{$manual}};
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
            $ref{title} =~ s/\s+/ /g;
            $ref{url} = "$url$ref{url}";
            $ref{url} = '' if not $url;
            my @out = ( $manual, $ref{section}, $ref{title}, $ref{url} );
            print join('::', @out) . "\n";
        }
    }

    close(INDEX);
}

# vim: sw=4 sts=4 ts=4 et sr
