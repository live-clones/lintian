# Checker -- Perl checker functions for lintian

# Copyright (C) 2004 Jeroen van Wolffelaar
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

package Checker;
use strict;
no strict 'refs';

# Quiet "Name "main::LINTIAN_ROOT" used only once"
# The variable comes from 'lintian'
() = $main::LINTIAN_ROOT;
my $LINTIAN_ROOT = $main::LINTIAN_ROOT;
my $debug = $::debug;

sub runcheck {
	my ($pkg, $type, $info, $name) = @_;

	# Will be set to 2 if error is encountered
	my $return = 0;

	print "N: Running check: $name ...\n" if $debug;

	# require has an anti-require-twice cache
	require "$LINTIAN_ROOT/checks/$name";

	$name =~ s/[-.]/_/g;
	eval { &{'Lintian::'.$name.'::run'}($pkg, $type, $info) };
	if ( $@ ) {
	    print STDERR $@;
	    print STDERR "internal error: cannot run $name check on package $pkg\n";
	    $return = 2;
	}

	return $return;
}

1;

# Local Variables:
# indent-tabs-mode: t
# cperl-indent-level: 8
# End:
# vim: ts=4 sw=4 noet
