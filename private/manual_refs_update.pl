#!/usr/bin/perl -w

# Copyright (C) 2001 Colin Watson
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
# Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
# MA 02111-1307, USA.

# Invoke as ./manual_refs_update.pl manual_refs > manual_refs.new
# You need copies of all the relevant manuals installed in the standard
# places locally.

# Currently, this is only likely to work with the HTML output by
# DebianDoc-SGML. This seems to be OK for all the necessary manuals for now.

use strict;

# Location of the manual directory on the local filesystem, and base URL for
# the eventual target of the reference.

my %manuals = (
    'policy'    => [ '/usr/share/doc/debian-policy/policy.html',
                     'http://www.debian.org/doc/debian-policy' ],
    'devref'    => [ '/usr/share/doc/developers-reference/' .
                        'developers-reference.html',
                     'http://www.debian.org/doc/packaging-manuals/' .
                        'developers-reference' ],
    'menu'      => [ '/usr/share/doc/menu/html',
                     'http://www.debian.org/doc/packaging-manuals/menu.html' ],
);

my %refs;

for my $manual (keys %manuals) {
    my ($dir, $url) = @{$manuals{$manual}};
    my @chapter_refs;

    unless (-d $dir) {
        print STDERR "Manual '$manual' not installed; not updating.\n";
        next;
    }
    $refs{$manual} = [ "$manual $url/index.html" ];

    local *DIR;
    opendir DIR, $dir or die "Couldn't open $dir: $!";
    while (defined(my $file = readdir DIR)) {
        next unless -f "$dir/$file";
        my $chapter;
        local *FILE;
        open FILE, "< $dir/$file" or
            die "Couldn't open $dir/$file: $!";
        while (<FILE>) {
            if (m/^Chapter (\d+)/ and not defined $chapter) {
                $chapter = $1;
                push @{$chapter_refs[$chapter]}, "$manual-$1 $url/$file";
            }
            elsif (m/<a name="(.+?)">(\d.*?) /) {
                if (defined $chapter) {
                    push @{$chapter_refs[$chapter]},
                         "$manual-$2 $url/$file#$1";
                } else {
                    print STDERR "No 'Chapter' line in $dir/$file; ",
                                 "ignoring this file.\n";
                    next;
                }
            }
        }
        close FILE;
    }
    closedir DIR;

    for my $chapter_ref (@chapter_refs) {
        next unless defined $chapter_ref;
        push @{$refs{$manual}}, @$chapter_ref;
    }
}

# Replace all lines for manuals for which we have up-to-date information.

my %seen;

while (<>) {
    next unless m/^(\w+)/;
    my $manual = $1;
    next if $seen{$manual};
    if (exists $manuals{$manual} and exists $refs{$manual}) {
        $seen{$manual} = 1;
        print join("\n", @{$refs{$manual}}), "\n";
    } else {
        print;
    }
}
