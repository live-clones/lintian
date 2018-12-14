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
    return $self->_send('skip', $reason);
}

sub pass_test {
    my ($self) = @_;
    return $self->_send('pass');
}

sub pass_todo_test {
    my ($self, $msg) = @_;
    return $self->_send('pass-todo', $msg);
}

sub test_error {
    my ($self, $msg) = @_;
    #confess('ERROR $msg' . NEWLINE);
    return $self->_send('error', $msg);
}

sub dump_log {
    my ($self, $logfile) = @_;
    return $self->_send('dump-file', $logfile);
}

sub diff_files {
    my ($self, $original, $actual) = @_;
    return $self->_send('diff-files', $original, $actual);
}

sub fail_test {
    my ($self, $msg, $extra_info_cmd) = @_;
    return $self->_send('fail', $msg, $extra_info_cmd);
}

sub _send {
    my ($self, $msg_type, @msg) = @_;
    $self->{'_output'}->send([$msg_type, $self->{'_test_metadata'}, @msg]);
    return;
}

1;
