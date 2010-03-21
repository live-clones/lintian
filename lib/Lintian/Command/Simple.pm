# Copyright (C) 2010 Raphael Geissert <atomo64@gmail.com>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Command::Simple;

use strict;
use warnings;

=head1 NAME

Lintian::Command::Simple - Run commands without pipes

=head1 SYNOPSIS

    use Lintian::Command::Simple;

    Lintian::Command::Simple::run("echo", "hello world");

    # Start a command in the background:
    Lintian::Command::Simple::background("sleep", 10);
    print (Lintian::Command::Simple::wait())? "success" : "failure";

    # Using the OO interface

    my $cmd = Lintian::Command::Simple->new();

    $cmd->run("echo", "hello world");

    $cmd->background("sleep", 10);
    print ($cmd->wait())? "success" : "failure";


=head1 DESCRIPTION

Lintian::Command::Simple allows running commands with the capability of
running them "in the background" (asynchronously.)

Pipes are not handled at all, except for those handled internally by
the shell. See 'perldoc -f exec's note about shell metacharacters.
If you want to pipe to/from Perl, look at Lintian::Command instead.

A procedural and an Object-Oriented (from now on OO) interfaces are
provided.

It is possible to reuse an object to run multiple commands, but only
after reaping the previous command.

=item new()

Creates a new Lintian::Command::Simple object and returns a reference
to it.

=cut

sub new {
    my ($class, $pkg) = @_;
    my $self = {};
    bless($self, $class);
    return $self;
}

=item run(command, argument  [, ...])

Executes the given C<command> with the given arguments and returns the
status code as one would see it from a shell script.

Being fair, the only advantage of this function (or method) over the
CORE::system() function is the way the return status is reported.

=cut

sub run {
    my $self;

    if (ref $_[0]) {
	$self = shift;
	return -1
	    if defined($self->{'pid'});
    }

    system(@_);

    $self->{'status'} = $?
	if defined $self;

    return $? >> 8;
}

=item background(command, argument  [, ...])

Executes the given C<command> with the given arguments asynchronously
and returns the process id of the child process.

A return value of -1 indicates an error. This can either be a problem
when calling CORE::fork() or when trying to run another command before
calling wait() to reap the previous command.

=cut

sub background {
    my $self;

    if (ref $_[0]) {
	$self = shift;
	return -1
	    if (defined($self->{'pid'}));

	$self->{'status'} = undef;
    }

    my $pid = fork();

    if (not defined($pid)) {
	# failed
	return -1;
    } elsif ($pid > 0) {
	# parent

	$self->{'pid'} = $pid
	    if (defined($self));

	return $pid;
    } else {
	# child
	close(STDIN);
	open(STDIN, '<', '/dev/null');

	CORE::exec @_ or die("Failed to exec '$_[0]': $!\n");
    }
}

=item wait([pid|hashref])

When called as a function:
If C<pid> is specified, it waits until the given process (which must be
a child of the current process) returns. If C<pid> is not specified, it
waits for any child process to finish and returns.

When called as a method:
It takes no argument. It waits for the previously background()ed process to
return.

The return value is either -1, probably indicating an error, or the
return status of the process as it would be seen from a shell script.
See 'perldoc -f wait' for more details about the possible meanings of
-1.


To reap one from many:

When starting multiple processes asynchronously, it is common to wait
until the first is done. While the CORE::wait() function is usually
used for that very pourpose, it does not provide the desired results
when the processes were started via the OO interface.

To help with this task, wait() can take a hash ref where the value of
each entry is an instance of Lintian::Command::Simple. The key of each
entry is irrelevant and is not used for any pourpose.

Under this mode, wait() waits until any child process is done and if the
deceased process is one of the set passed via the hash ref it marks it
as reaped and stores the return status.
The results and return value are undefined when under this mode wait()
"accidentally" reaps a process not started by one of the objects passed
in the hash ref.

The return value in scalar context is the instance of the object that
started the now deceased process. In list context, the key and value
(i.e. the object instance) are returned.
Whenever CORE::wait() would return -1, wait() returns undef or a null
value so that it is safe to:

    while($cmd = Lintian::Command::Simple::wait(\%hash)) { something; }

The same is true whenever the hash reference points to an empty hash.

Passing any other kind of reference or value as arguments has undefined
results.

=cut

sub wait {
    my ($self, $pid);

    if (ref $_[0] eq "Lintian::Command::Simple") {
	$self = shift;
	$pid = $self->{'pid'};
    } else {
	$pid = shift;
    }

    if (defined($pid) && !ref $pid) {
	$self->{'pid'} = undef
	    if defined($self);

	my $ret = waitpid($pid, 0);
	my $status = $?;

	$self->{'status'} = $?
	    if defined($self);

	return ($ret == -1)? -1 : $status >> 8;
    } elsif (defined($pid)) {
	# in this case $pid is a ref (must be a hash ref)
	# rename it accordingly:
	my $jobs = $pid;
	$pid = 0;

	my ($reaped_pid, $reaped_status);

	# count the number of members and reset the internal hash iterator
	if (scalar keys %$jobs == 0) {
	    if (wantarray) {
		return ();
	    } else {
		return undef;
	    }
	}

	$reaped_pid = CORE::wait();
	$reaped_status = $?;

	if ($reaped_pid == -1) {
	    if (wantarray) {
		return ();
	    } else {
		return undef;
	    }
	}

	while (my ($k, $cmd) = each %$jobs) {
	    next unless (defined($cmd->pid()) && $reaped_pid == $cmd->pid());

	    $cmd->status($reaped_status)
		or die("internal error: object of pid $reaped_pid " .
			"failed to recognise its termination\n");

	    if (wantarray) {
		return ($k, $cmd);
	    } else {
		return $cmd;
	    }
	}
    } elsif (not defined($self)) {
	return (CORE::wait() == -1)? -1 : ($? >> 8);
    } else {
	return -1;
    }
}

=item pid()

Only available under the OO interface, it returns the pid of a
background()ed process.

After calling wait(), this method always returns undef.

=cut

sub pid {
    my $self = shift;

    return $self->{'pid'};
}

=item status()

Only available under the OO interface, it returns the return status of
the background()ed or run()-ran process.

When used on async processes, it is only defined after calling wait().

B<Note>: it is also the method internally used by wait() to set the return
status in some cases.

=cut

sub status {
    my $self = shift;
    my $status = shift;

    # Externally set the return status.
    # It performs a sanity check by making sure the executed command is
    # indeed done.
    if (defined($status)) {
	my $rstatus = $self->wait();

	return 0 if ($rstatus != -1);

	$self->{'status'} = $status;
	return 1;
    }

    return (defined $self->{'status'})? $self->{'status'} >> 8 : undef;
}

1;

__END__

=back
=head1 TODO

Provide the necessary methods to modify the environment variables of
the to-be-executed commands.  This would let us drop C<system_env> (from
lib/Util.pm) and make C<run> more useful.

=head1 NOTES

Unless specified by prefixing the package name, every reference to a
function/method in this documentation refers to the functions/methods
provided by this package itself.

=head1 CAVEATS

Combining asynchronous jobs from Lintian::Command and calls to wait()
can lead to unexpected results.

Calling wait() without a pid via the procedural interface can lead to
processes started via the OO interface to be reaped. In this case, the
object that started the reaped process won't be able to determine the
return status, which can affect the rest of the application.

As a general advise, the procedural and OO interfaces should not be
combined when using background(). Unless, of course, you are calling wait()
with a hash ref.

=head1 AUTHOR

Originally written by Raphael Geissert <atomo64@gmail.com> for Lintian.

=cut
