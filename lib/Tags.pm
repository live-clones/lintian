# Tags -- Perl tags functions for lintian
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

package Tags;
use strict;

use Exporter 'import';
our @EXPORT = qw(tag);

my $LINTIAN_ROOT = $::LINTIAN_ROOT;

# Can also be more precise later on (only verbose with lab actions) but for
# now this will do --Jeroen
my $verbose = $::verbose;
my $debug = $::debug;

# What to print between the "E:" and the tag, f.e. "package source"
my $prefix = undef;

# The master hash with all tag info. Key is a hash too, with these stuff:
# - tag: short name
# - type: error/warning/info/experimental
# - info: Description in HTML
# - ref: Any references
# - experimental: experimental status (possibly undef)
my %tags;

my $codes = { 'error' => 'E' , 'warning' => 'W' , 'info' => 'I' };

# Call this function to add a certain tag, by supplying the info as a hash
sub add_tag {
	my $newtag = shift;
	fail("Duplicate tag: $newtag->{'tag'}")
		if exists $tags{$newtag->{'tag'}};
	
	$tags{$newtag->{'tag'}} = $newtag;
}

sub tag {
	my $tag = shift;
	my $info = $tags{$tag};
	my $extra = '';
	$extra = ' '.join(' ', map { s,\n,\\n, } @_) if $#_ >=0;

	print "$codes->{$info->{'type'}}: $prefix: $tag$extra\n";
}

1;

# vim: ts=4 sw=4 noet
