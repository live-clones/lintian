# -*- perl -*-
# Pipeline -- library of process spawn functions that do not invoke a shell

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

package Pipeline;
use strict;

use Exporter 'import';
our @EXPORT = qw(spawn pipeline pipeline_open pipeline_pure);

use Fcntl;


# This is used to avoid END blocks and such, when exiting from
# children that have not execed.
use POSIX;
sub immediate_exit { POSIX::_exit($_[0] + 0); }

# The pipeline function takes a list of coderefs, which are forked off
# as processes.  The stdout of each is connected to the stdin of the
# next.

# The coderefs will usually be 'exec' calls.  If the code does return,
# the process will exit with the return value of that code.  That way
# you don't have to check if the exec succeeded.
#
# Use an explicit exit statement if you don't want this.

# The first list element may be a filename instead of a coderef, in which
# case it will be opened as stdin for the first process.
# The last list element may also be a filename instead of a coderef, in
# which case it will be opened as stdout for the last process.

# pipeline() returns the exit value of the last process in the pipe,
# or 255 if the exec failed.

sub pipeline {
    my $i;
    my $pid = fork();
    defined $pid or return 255;

    if (not $pid) {		# child
	sysopen(STDIN, shift, O_RDONLY)
	    or fail("$$: cannot redirect input: $!")
		unless ref($_[0]) eq "CODE";
	sysopen(STDOUT, pop, O_WRONLY|O_CREAT|O_TRUNC)
	    or fail("$$: cannot redirect output: $!")
		unless ref($_[$#_]) eq "CODE";

	# Perhaps I should submit this to the obfuscated perl contest.
	$i = @_ or immediate_exit 0;
	$pid = open(STDIN, "-|") while $pid == 0 and --$i;
	defined $pid or fail("cannot fork: $!");
	immediate_exit int(&{$_[$i]});
    } else {			# parent
	waitpid($pid, 0);
	return $?;
    }
}

# pipeline_open is just like pipeline, except that it takes a filehandle
# as its first argument, and cannot take both an input filename and
# an output filename.  It connects the filehandle to stdout of the
# last process if no output filename is given, and connects it to
# stdin of the first process otherwise.  (Be sure to handle SIGPIPE
# if you do the latter).
# pipeline_open() returns the pid of the child process, or undef if it failed.

sub pipeline_open (*@) {
    my ($i, $pid);
    if (ref($_[$#_]) eq "CODE") {
	$pid = open(shift, "-|");
    } else {
	$pid = open(shift, "|-");
    }
    defined $pid or return undef;

    if (not $pid) {		# child
	sysopen(STDIN, shift, O_RDONLY)
	    or fail("$$: cannot redirect input: $!")
		unless ref($_[0]) eq "CODE";
	sysopen(STDOUT, pop, O_WRONLY|O_CREAT|O_TRUNC)
	    or fail("$$: cannot redirect output: $!")
		unless ref($_[$#_]) eq "CODE";

	$i = @_ or immediate_exit 0;
	$pid = open(STDIN, "-|") while $pid == 0 and --$i;
	defined $pid or fail("cannot fork: $!");
	immediate_exit int(&{$_[$i]});
    }
    # parent does nothing
    return $pid;
}

# Fork off a single process that immediately execs.  It has a simpler
# calling syntax than pipeline() with only one argument.

# It returns the exit code of the execed process, or 255 if the
# fork or exec failed.

sub spawn {
    my $pid = fork();
    defined $pid or return 255;

    if (not $pid) {		# child
	exec @_ or immediate_exit 255;
    } else {
	waitpid($pid, 0);
	return $?;
    }
}

# This is just an experiment to see if the loop alone is useful.
# It looks like it isn't.
#sub pipeline_pure {
#    my $pid = 0;
#    my $i = @_ or return;
#    $pid = open(STDIN, "-|") while $pid == 0 and --$i;
#    defined $pid or fail("cannot fork: $!");
#    &{$_[$i]};
#    close(STDIN) or fail("child process failed: $?") if $pid;
#    immediate_exit 0 unless $i == $#_;
#}

1;
