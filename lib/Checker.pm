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
no strict 'refs';

use Pipeline;
use Tags;
use Cwd 'cwd';

my $LINTIAN_ROOT = $::LINTIAN_ROOT;

# Can also be more precise later on (only verbose with checker actions) but for
# now this will do --Jeroen
my $verbose = $::verbose;
my $debug = $::debug;

# Not very neat to do like this... but the code wasn't neat to begin with :-/
my $display_infotags = $::display_infotags;
my $no_override = $::no_override;
my $show_overrides = $::show_overrides;

my %checks;

# Register a check. Argument is a hash with info
sub register {
	my $info = $_[0];
	fail("Duplicate check $info->{'check-script'}")
		if exists $checks{$info->{'check-script'}};

	$checks{$info->{'check-script'}} = $info;
}

sub runcheck {
	my $pkg = shift;
	my $type = shift;
	my $name = shift;

	# Will be set to 1 if error is encountered
	my $return = 0;

	print "N: Running check: $name ...\n" if $debug;

	my $check = $checks{$name};

	# require has a anti-require-twice cache
	require "$LINTIAN_ROOT/checks/$name";

	$Tags::prefix = $type eq 'binary' ? $pkg : "$pkg $type";
	#Tags::reset();

	#print STDERR "Now running $name...\n";
	$name =~ s/[-.]/_/g;
	&{'Lintian::'.$name.'::run'}($pkg, $type);

	return $return;
}

1;

# vim: ts=4 sw=4 noet
