# -*- perl -*-

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
# Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
# MA 02111-1307, USA.

# Functions are defined here to read a shell script and return it as
# a list of tokens.

# We do NOT do history expansion, because it's normally turned off in
# shell scripts.  

# Possible tokens:
# literal:
#  <<- << >> && || <> >| >& ;; (( <& >& ( ) < > ; & | -
#
# end of line: EOL

use strict;

sub scan_script {
    my $tokenval = '';
    my @tokens = ();
    my $state = 0; #base
    my $reserved_ok = 1;
    my $line = 1;

    foreach (split(/\n/, $_[0])) {
	if ($state == 0) {  # base
	    s/^\s+//;               # skip leading whitespace
	    if (m/^\#|^$/) {
		# skip blank lines, skip comments till end of line
		push(@tokens, 'EOL');
		$reserved_ok = 1;
		$line++;
		next;
	    }

	    elsif (s/^( <<- | << | >> | <> | >\| | >& )//x) {
		push(@tokens, $1);
		$reserved_ok = 0;
		redo;
	    }

	    elsif (s/^( && | \|\| )//x) {
		push(@tokens, $1);
		$reserved_ok = 1;
		redo;
	    }

	    elsif (s/^ ;; //x) {
		push(@tokens, ';;');
		$state = 1; # case pattern
		$reserved_ok = 1;
		redo;
	    }

	    elsif ($reserved_ok and s/^ \(\( //x) {
		push(@tokens, '((');
		$state = 2; # dparen arithmetic
		redo;
		# XXX parse_arith_cmd
	    }

	    elsif (s/^( <& | >& )//x) {
		push(@tokens, $1);
		# hack <& - and >& - cases.
		# No comments or newlines can appear between the <& and -.
		if (s/^ \s* -//x) {
		    push(@tokens, '-');
		}
		$reserved_ok = 0; 
		redo;
	    }

	    elsif (m/^( <\( | >\( )/x) {
		$state = 3; # word
		$reserved_ok = 0;
		redo;
	    }

	    elsif (s/^( < | > )//x) {
		push (@tokens, $1);
		$reserved_ok = 0;
		redo;
	    }

	    elsif (s/^([();&|])//) {
		push (@tokens, $1);
		$reserved_ok = 1;
		redo;
	    }
	    
	    else {
		$state = 3; # word
		redo;
	    }
	}

    }

    return @tokens;
}

