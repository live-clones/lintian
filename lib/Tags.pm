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

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(tag);

my $LINTIAN_ROOT = $::LINTIAN_ROOT;

# Can also be more precise later on (only verbose with lab actions) but for
# now this will do --Jeroen
my $verbose = $::verbose;
my $debug = $::debug;

# What to print between the "E:" and the tag, f.e. "package source"
our $prefix = undef;
our $show_info = 0;

# The master hash with all tag info. Key is a hash too, with these stuff:
# - tag: short name
# - type: error/warning/info/experimental
# - info: Description in HTML
# - ref: Any references
# - experimental: experimental status (possibly undef)
my %tags;

our $show_overrides;
# in the form overrides->tag or full thing
my %overrides;

my $codes = { 'error' => 'E' , 'warning' => 'W' , 'info' => 'I' };


# TODO
# - override support back in --> just the unused reporting
# - be able to return whether any errors were there, better, full stats

# Call this function to add a certain tag, by supplying the info as a hash
sub add_tag {
	my $newtag = shift;
	fail("Duplicate tag: $newtag->{'tag'}")
		if exists $tags{$newtag->{'tag'}};
	
	$tags{$newtag->{'tag'}} = $newtag;
}

# Used to reset the matched tags data
sub pkg_reset {
	$prefix = shift;
	*overrides = {};
}

# Add an override, string tag, string rest
sub add_override {
	my $tag = shift;
	$overrides{$tag} = 0;
}


sub tag {
	my $tag = shift;
	my $info = $tags{$tag};
	return if not $show_info and $info->{'type'} eq 'info';
	my $extra = '';
	$extra = ' '.join(' ', @_) if $#_ >=0;
	$extra = '' if $extra eq ' ';
	my $code = $codes->{$info->{'type'}};
	if (exists $overrides{$tag} or exists $overrides{"$tag$extra"}) {
		return unless $show_overrides or $verbose;
		$code = 'O';
	}

	print "$code: $prefix: $tag$extra\n";
}

1;

# vim: ts=4 sw=4 noet
