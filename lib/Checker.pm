# Checker -- Perl checker functions for lintian
# $Id$

# Copyright (C) 1998-2004 Various authors
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

package Checker;
use strict;

use Pipeline;

my $LINTIAN_ROOT = $::LINTIAN_ROOT;

# Can also be more precise later on (only verbose with checker actions) but for
# now this will do --Jeroen
my $verbose = $::verbose;
my $debug = $::debug;

# Not very neat to do like this... but the code wasn't neat to begin with :-/
my $display_infotags = $::display_infotags;
my $no_override = $::no_override;
my $show_overrides = $::show_overrides;
# I want a reference... Yes it's very evil
my %experimental_tag; *experimental_tag = \%::experimental_tag;


sub runcheck {
	my $pkg = shift;
	my $type = shift;
	my $name = shift;

	# Will be set to 1 if error is encountered
	my $return = 0;
	my %overridden;

	print "N: Running check: $name ...\n" if $debug;

	my $cmd = "$LINTIAN_ROOT/checks/$name";

	my $PIPE=FileHandle->new;
	unless (pipeline_open($PIPE, sub { exec $cmd, $pkg, $type })) {
		print STDERR "internal error: cannot open input pipe to command $cmd: $!\n";
		return 2;
	}
	my $suppress;
	while (<$PIPE>) {
		chop;

		# error/warning/info ?
		if (/^[EWI]: \S+ \S+:\s+\S+/o) {
			$suppress = (/^I: / and not $display_infotags);

			# change "pkg binary:" to just "pkg:"
			s/^(.: \S+)\s+binary:/$1:/;

			# remove `[EWI]:' for override matching
			my $tag_long = $_;
			$tag_long =~ s/^.:\s+//;
			$tag_long =~ s/\s+$//;
			$tag_long =~ s/\s+/ /g;

			my $tag_short;
			if ($tag_long =~ /^([^:]*): (\S+)/) {
				$tag_short = "$1: $2";
			} else {
				die "couldn't parse tag_long $tag_long to create tag_short";
			}

			if ($experimental_tag{$2}) {
				s/^.:/X:/;
			}

			# overridden?
			if (not $no_override and
				((exists $overridden{$tag_long}) or
				 (exists $overridden{$tag_short}))) {
				# yes, this tag is overridden
				$overridden{$tag_long}++ if exists $overridden{$tag_long};
				$overridden{$tag_short}++ if exists $overridden{$tag_short};
				s/^.:/O:/;
				print "$_\n"
					if $show_overrides or ($verbose and not $suppress);
			} else {
				# no, just display it
				print "$_\n"
					if not $suppress;
			}

			# error?
			if (/^E:/) {
				$return = 1;
			}
		} else {
			# no, so just display it
			print "$_\n";
		}
	}
	unless (close($PIPE)) {
		if ($!) {
			print STDERR "internal error: cannot close input pipe to command $cmd: $!";
		} else {
			print STDERR "internal error: cannot run $name check on package $pkg\n";
		}
		return 2;
	}

	return $return;
}

1;

# vim: ts=4 sw=4 noet
