# Copyright © 1998 Richard Braakman
# Copyright © 2008 Frank Lichtenheld
# Copyright © 2008, 2009 Russ Allbery
# Copyright © 2014 Niels Thykier
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

# The harness for Lintian's test suite.  For detailed information on
# the test suite layout and naming conventions, see t/tests/README.
# For more information about running tests, see
# doc/tutorial/Lintian/Tutorial/TestSuite.pod
#

package Test::State;

=head1 NAME

Test::State -- Functions for inter-process communications for tests

=head1 SYNOPSIS

  use Test::State;
  use IO::Async::Channel;

  my $testcase = {};
  my $child_out_ch = IO::Async::Channel->new;

  my $state = Test::State->new($testcase, $child_out_ch);

=head1 DESCRIPTION

Functions for permanent test worker threads to communicate with the
harness.

=cut

use strict;
use warnings;
use autodie;

sub new {
    my ($class, $metadata, $output) = @_;
    my $self = {
        '_output' => $output,
        '_test_metadata' => $metadata,
    };
    return bless($self, $class);
}

sub info_msg {
    my ($self, $verbosity, $msg) = @_;
    return $self->_send('log-msg', $verbosity, $msg);
}

sub progress {
    my ($self, $msg) = @_;
    return $self->_send('progress', $msg);
}

sub skip_test {
    my ($self, $reason) = @_;
    $self->announce('skip', $reason);
    $self->mark_skipped($reason);
    $self->done;
    return;
}

sub pass_test {
    my ($self) = @_;
    $self->announce('pass');
    $self->done;
    return;
}

sub pass_todo_test {
    my ($self, $msg) = @_;
    $self->announce('pass-todo', $msg);
    $self->done;
    return;
}

sub test_error {
    my ($self, $msg) = @_;
    $self->announce('error', $msg);
    $self->mark_failed;
    $self->stop_others;
    $self->done;
    return;
}

sub dump_log {
    my ($self, $logfile) = @_;
    return $self->_send('dump-file', $logfile);
}

sub fail_test {
    my ($self, @args) = @_;
    $self->announce('fail', @args);
    $self->mark_failed;
    $self->stop_others;
    $self->done;
    return;
}

sub announce {
    my ($self, @args) = @_;
    $self->_send('announce', @args);
    return;
}

sub mark_skipped {
    my ($self, @args) = @_;
    $self->_send('mark-skipped', @args);
    return;
}

sub mark_failed {
    my ($self) = @_;
    $self->_send('mark-failed');
    return;
}

sub diff_files {
    my ($self, @args) = @_;
    $self->_send('diff-files', @args);
    return;
}

sub stop_others {
    my ($self) = @_;
    $self->_send('stop-others');
    return;
}

sub done {
    my ($self) = @_;
    $self->_send('done');
    return;
}

sub _send {
    my ($self, $msg_type, @msg) = @_;
    $self->{'_output'}->send([$msg_type, $self->{'_test_metadata'}, @msg]);
    return;
}

1;
