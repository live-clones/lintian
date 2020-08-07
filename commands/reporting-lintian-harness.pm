#!/usr/bin/perl -w

# Lintian reporting harness -- Run lintian against an archive mirror
#
# Copyright © 2015 Niels Thykier
# Copyright © 2018 Chris Lamb <lamby@debian.org>
#
# Based on "reporting/harness", which was:
# Copyright © 1998 Christian Schwarz and Richard Braakman
#
# This program is free software.  It is distributed under the terms of
# the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any
# later version.
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

package reporting_lintian_harness;

use v5.20;
use warnings;
use utf8;
use autodie;

use constant BACKLOG_PROCESSING_TIME_LIMIT => 4 * 3600; # 4hours

use Fcntl qw(F_GETFD F_SETFD FD_CLOEXEC SEEK_END);
use File::Basename qw(basename);
use File::Temp qw(tempfile);
use Getopt::Long();
use IO::Async::Loop;
use IO::Async::Process;
use List::MoreUtils qw(first_index);
use POSIX qw(strftime);

use Lintian::IO::Async qw(safe_qx);
use Lintian::Reporting::Util
  qw(find_backlog load_state_cache save_state_cache);

use constant EMPTY => q{};
use constant COLON => q{:};
use constant NEWLINE => qq{\n};

my (@LINTIAN_CMD, $LINTIAN_VERSION);

my @REQUIRED_PARAMETERS = qw(
  lintian-log-dir
  schedule-chunk-size
  schedule-limit-groups
  state-dir
);
my %OPT = ('lintian-frontend'  => 'lintian',);
my %OPT_HASH = (
    'schedule-chunk-size=i'   => \$OPT{'schedule-chunk-size'},
    'schedule-limit-groups=i' => \$OPT{'schedule-limit-groups'},
    'state-dir=s'             => \$OPT{'state-dir'},
    'lintian-frontend=s'      => \$OPT{'lintian-frontend'},
    'lintian-log-dir=s'       => \$OPT{'lintian-log-dir'},
    'lintian-scratch-space=s' => \$OPT{'lintian-scratch-space'},
    'help|h'                  => \&usage,
);

sub main {
    STDOUT->autoflush;
    Getopt::Long::config('bundling', 'no_getopt_compat', 'no_auto_abbrev');
    Getopt::Long::GetOptions(%OPT_HASH) or die("error parsing options\n");
    check_parameters();
    $LINTIAN_VERSION= safe_qx($OPT{'lintian-frontend'}, '--print-version');
    chomp($LINTIAN_VERSION);
    prepare_lintian_environment_and_cmdline();
    exit(harness_lintian());
}

### END OF SCRIPT -- below are helper subroutines ###

=item untaint(VALUE)

Untaint VALUE

=cut

sub untaint {
    return $_[0] = $1 if $_[0] =~ m/^(.*)$/;
    return;
}

sub check_parameters {
    for my $parameter (@REQUIRED_PARAMETERS) {
        if (not defined($OPT{$parameter})) {
            die(    "Missing required parameter \"--${parameter}\""
                  . "(use --help for more info)\n");
        }
    }
    if (-d $OPT{'state-dir'}) {
        untaint($OPT{'state-dir'});
    } else {
        die("The --state-dir parameter must point to an existing directory\n");
    }
    die("The argument for --schedule-limit-groups must be an > 0\n")
      if $OPT{'schedule-limit-groups'} < 1;

    return;
}

sub prepare_lintian_environment_and_cmdline {
    my $frontend = 'lintian';
    my $eoa_marker_index = first_index { $_ eq '--' } @ARGV;
    my $logs_dir = $OPT{'lintian-log-dir'};
    my @overridable_args = (qw(-EL +>=classification --show-overrides));
    my @args = (
        qw(--verbose), # We rely on this for filtering the log
        qw(--exp-output=format=fullewi --packages-from-file -),
        qw(--perf-debug --perf-output),
        "+${logs_dir}/lintian-perf.log",
    );
    $frontend = $OPT{'lintian-frontend'} if ($OPT{'lintian-frontend'});

    if ($eoa_marker_index > -1) {
        # Move known "non-parameters" and the "--" behind our arguments.
        # It is a misfeature, but at least it does not break
        # our code.  NB: It requires *two* "--" on the command-line to
        # trigger this case.
        push(@args, splice(@ARGV, $eoa_marker_index));
    }
    # Put "our" arguments after user supplied ones
    @LINTIAN_CMD = ($frontend, @overridable_args, @ARGV, @args);

    # The environment part
    for my $key (keys(%ENV)) {
        delete($ENV{$key}) if $key =~ m/^LINTIAN_/;
    }
    if ($OPT{'lintian-scratch-space'}) {
        $ENV{'TMPDIR'} = $OPT{'lintian-scratch-space'};
        log_msg("Setting TMPDIR to $ENV{'TMPDIR'}");
    } else {
        log_msg('Leaving TMPDIR unset (no --lintian-scratch-space');
    }
    return;
}

sub log_msg {
    my ($msg) = @_;
    my $ts = strftime('[%FT%T]: ', localtime());
    print $ts, $msg, "\n";
    return;
}

sub harness_lintian {
    my (@worklist);
    my $exit_code = 0;
    my $state = load_state_cache($OPT{'state-dir'});
    my $lintian_log_dir = $OPT{'lintian-log-dir'};
    my $lintian_log = "${lintian_log_dir}/lintian.log";
    log_msg('Update complete, loading current state information');

    @worklist = find_backlog($LINTIAN_VERSION, $state);

    # Always update the log if it exists, as we may have removed
    # some entries.
    if (-f $lintian_log) {
        my $filter = generate_log_filter($state, {});

        # update lintian.log
        log_msg('Updating lintian.log...');
        rewrite_lintian_log($filter);
    }

    log_msg('');

    if (not @worklist) {
        log_msg('Skipping Lintian run - nothing to do...');
    } else {
        log_msg('Processing backlog...');
        if (@worklist > $OPT{'schedule-limit-groups'}) {
            log_msg(
                    "Truncating worklist to size $OPT{'schedule-limit-groups'}"
                  . ' from '
                  . (scalar(@worklist)));
            @worklist = splice(@worklist, 0, $OPT{'schedule-limit-groups'});
        }
        $exit_code= process_worklist(\@worklist, $state, $lintian_log_dir);
    }
    return $exit_code;
}

sub process_worklist {
    my ($worklist_ref, $state, $lintian_log_dir) = @_;
    my $round = 0;
    my $rounds = 1;
    my @worklist = @{$worklist_ref};
    my $exit_code = 0;
    my $schedule_chunk_size = $OPT{'schedule-chunk-size'};
    my $start_time = time();

    if ($schedule_chunk_size > 0) {
        # compute the number of rounds needed.
        my $size_up = scalar @worklist + ($schedule_chunk_size - 1);
        $rounds = int($size_up / $schedule_chunk_size);
    }

    log_msg(
        sprintf(
            'Groups to process %d will take %d round(s) [round limit: %s]',
            scalar @worklist,
            $rounds,$schedule_chunk_size > 0 ? $schedule_chunk_size : 'none'
        ));

    log_msg('Command line used: ' . join(q{ }, @LINTIAN_CMD));
    while (@worklist) {
        my $len = scalar @worklist;
        my (@work_splice, @completed, %processed, %errors);
        my ($status_fd, $lint_status_out);
        my $got_alarm = 0;

        # Bail if there is less than 5 minutes left
        if (time() >= $start_time + BACKLOG_PROCESSING_TIME_LIMIT - 300) {
            log_msg('No more time for processing backlogs');
            $exit_code = 2;
            last;
        }

        $round++;
        # correct bounds to fit chunk size
        if ($schedule_chunk_size > 0 and $len > $schedule_chunk_size) {
            $len = $schedule_chunk_size;
        }

        # Sort @work_splice to have the "Range:"-line below produce
        # reasonable output.
        @work_splice = sort(splice(@worklist, 0, $len));

        log_msg("Running Lintian (round $round/$rounds) ...");
        if ($len == 1) {
            log_msg(' - Single group: ' . $work_splice[0]);
        } else {
            log_msg(' - Range: GROUP:'
                  . $work_splice[0]
                  . q{ ... GROUP:}
                  . $work_splice[-1]);
        }

        next if ($OPT{'dry-run'});

        pipe($status_fd, $lint_status_out);
        my ($nfd, $new_lintian_log)
          = tempfile('lintian.log-XXXXXXX', DIR => $lintian_log_dir);
        # We do not mind if anyone reads the lintian log as it is being written
        chmod(0644, $nfd);
        log_msg("New lintian log at $new_lintian_log");

        my $loop = IO::Async::Loop->new;
        my $future = $loop->new_future;
        my $signalled_lintian = 0;

        push(@LINTIAN_CMD, '--status-log', '&3');
        my $process = IO::Async::Process->new(
            command => [@LINTIAN_CMD],
            stdin => { via => 'pipe_write' },
            stdout => { via => 'pipe_read' },
            stderr => { via => 'pipe_read' },
            fd3 => { via => 'pipe_read' },
            on_finish => sub {
                my ($self, $exitcode) = @_;
                my $status = ($exitcode >> 8);
                my $signal = ($exitcode & 0xff);

                if ($signal) {
                    log_msg("Lintian terminated by signal: $signal");
                    # If someone is sending us signals (e.g. SIGINT/Ctrl-C)
                    # don't start the next round.
                    log_msg(' - skipping the rest of the worklist');
                    @worklist = ();
                    $future->fail(
                        "Command @LINTIAN_CMD received signal $signal");
                    return;
                }

                if ($status == 0 || $status == 1) {
                    # exit 1 (policy violations) happens all the time (sadly)
                    # exit 2 (broken packages) also happens all the time...
                    log_msg('Lintian finished successfully');
                    $future->done("Done with @LINTIAN_CMD");
                    return;
                }

                log_msg("warning: executing lintian returned status $status");
                if ($got_alarm) {
                    # Ideally, lintian would always die by the signal
                    # but some times it catches it and terminates
                    # "normally"
                    log_msg('Stopped by a signal or time out');
                    log_msg(' - skipping the rest of the worklist');
                    @worklist = ();
                }

                $future->fail("Error status $status from @LINTIAN_CMD");
                return;
            });

        $process->stdout->configure(
            on_read => sub {
                my ($stream, $buffref, $eof) = @_;

                if (length $$buffref) {
                    print {$nfd} $$buffref;
                    $$buffref = EMPTY;
                }

                close($nfd)
                  if $eof;

                return 0;
            },
        );

        $process->stderr->configure(
            on_read => sub {
                my ($stream, $buffref, $eof) = @_;

                if (length $$buffref) {
                    print STDOUT $$buffref;
                    $$buffref = EMPTY;
                }

                return 0;
            },
        );

        $process->fd3->configure(
            on_read => sub {
                my ($stream, $buffref, $eof) = @_;

                while($$buffref =~ s/^(.*)\n//) {
                    my $line = $1;

                    # listen to status updates from lintian
                    if ($line =~ m/^complete ([^ ]+) \(([^\)]+)\)$/) {
                        my ($group_id, $runtime) = ($1, $2);
                        push(@completed, $group_id);
                        $processed{$group_id} = 1;
                        log_msg("  [lintian] processed $group_id"
                              . " successfully (time: $runtime)");
                    } elsif ($line =~ m/^error ([^ ]+) \(([^\)]+)\)$/) {
                        my ($group_id, $runtime) = ($1, $2);
                        log_msg("  [lintian] error processing $group_id "
                              . "(time: $runtime)");
                        $processed{$group_id} = 1;
                        # We ignore errors if we sent lintian a signal to avoid
                        # *some* false-positives.
                        $errors{$group_id} = 1 if not $signalled_lintian;
                    } elsif ($line =~ m/^ack-signal (SIG\S+)$/) {
                        my $signal = $1;
                        log_msg(
"Signal $signal acknowledged: disabled timed alarms"
                        );
                        alarm(0);
                    }
                }

                alarm(0)
                  if $eof;

                return 0;
            },
        );

        $loop->add($process);

        my $groups = $state->{'groups'};
        # Submit the tasks to Lintian
        foreach my $group_id (@work_splice) {
            my $members;
            if (not exists($groups->{$group_id})) {
                # Sanity check (can in theory happen if an external process
                # modifies the state cache and we have reloaded it)
                log_msg(
                    "Group ${group_id} disappeared before we could schedule it"
                );
                next;
            }
            $members = $groups->{$group_id}{'members'};
            for my $member_id (sort(keys(%{${members}}))) {
                my $path = $members->{$member_id}{'path'};
                $process->stdin->write($path . NEWLINE);
            }
        }
        $process->stdin->close_when_empty;

        eval {
            my $time_limit
              = $start_time + BACKLOG_PROCESSING_TIME_LIMIT - time();
            my $count = 0;
            my $sig_handler = sub {
                my ($signal_name) = @_;
                $signalled_lintian = 1;
                $count++;
                if ($signal_name eq 'ALRM') {
                    $got_alarm = 1 if $got_alarm >= 0;
                } else {
                    $got_alarm = -1;
                }
                if ($count < 3) {
                    my $pid = $process->pid;
                    log_msg("Received SIG${signal_name}, "
                          . "sending SIGTERM to $pid [${count}/3]");
                    $process->kill('TERM');
                    if ($signal_name eq 'ALRM') {
                        log_msg(
                            'Scheduling another alarm in 5 minutes from now...'
                        );
                        alarm(300);
                    }
                } else {
                    my $pid = $process->pid;
                    log_msg("Received SIG${signal_name} as the third one, "
                          . "sending SIGKILL to $pid");
                    log_msg('You may have to clean up some '
                          . 'temporary directories manually');
                    $process->kill('KILL');
                }
            };
            local $SIG{'TERM'} = $sig_handler;
            local $SIG{'INT'} = $sig_handler;
            local $SIG{'ALRM'} = $sig_handler;

            alarm($time_limit);
        };

        # Wait for lintian to terminate
        $future->await;

        if ($got_alarm) {
            if ($got_alarm == 1) {
                # Lintian was (presumably) killed due to a
                # time-out from this process
                $exit_code = 2;
            } else {
                # Lintian was killed by another signal; notify
                # harness that it should skip the rest as well.
                $exit_code = 3;
            }
        }

        log_msg('Updating the lintian log used for reporting');
        my $filter = generate_log_filter($state, \%processed);
        seek($nfd, 0, SEEK_END);
        update_lintian_log($filter, $nfd, $new_lintian_log);

        log_msg('Updating harness state cache');
        # Reload the state cache, just in case it was modified by an external
        # process during the lintian run.
        $state = load_state_cache($OPT{'state-dir'});
        for my $group_id (@completed) {
            my $group_data;
            # In theory, they can disappear - in practise, that requires
            # an external call to (e.g.) lintian reporting-sync-state.
            next if not exists($state->{'groups'}{$group_id});
            $group_data = $state->{'groups'}{$group_id};
            $group_data->{'last-processed-by'} = $LINTIAN_VERSION;
            delete($group_data->{'out-of-date'});
            # Always clear the error counter after a successful run.
            delete($group_data->{'processing-errors'});
            delete($group_data->{'last-error-by'});
        }
        for my $group_id (sort(keys(%errors))) {
            my $group_data;
            # In theory, they can disappear - in practise, that requires
            # an external call to (e.g.) lintian reporting-sync-state.
            next if not exists($state->{'groups'}{$group_id});
            $group_data = $state->{'groups'}{$group_id};
            if ($errors{$group_id}) {
                if (not exists($group_data->{'last-error-by'})
                    or $group_data->{'last-error-by'} ne $LINTIAN_VERSION) {
                    # If it is a new lintian version then (re)set the counter
                    # to 1.  Case also triggers for the very first issue.
                    $group_data->{'processing-errors'} = 1;
                } else {
                    # Repeated error with the same version
                    ++$group_data->{'processing-errors'};
                }
                # Set the "last-error-by" flag so we can clear the
                # error if there is a new version of lintian.
                $group_data->{'last-error-by'} = $LINTIAN_VERSION;
            } else {
                delete($group_data->{'processing-errors'});
            }
        }
        save_state_cache($OPT{'state-dir'}, $state);
        last if $exit_code;
    }
    return $exit_code;
}

sub generate_log_filter {
    my ($state, $exclude) = @_;
    my %filter;
    my $group_map = $state->{'groups'};
    for my $group_id (keys(%{${group_map}})) {
        my $members;
        next if exists($exclude->{$group_id});
        $members = $group_map->{$group_id}{'members'};
        for my $member_id (keys(%{$members})) {
            $filter{$member_id} = 1;
        }
    }
    return \%filter;
}

sub update_lintian_log {
    my ($keep_filter, $new_fd, $tmp_path) = @_;
    my $lintian_log_dir = $OPT{'lintian-log-dir'};
    my $lintian_log = "${lintian_log_dir}/lintian.log";
    my $copy_mode = 0;
    my $first = 1;

    eval {
        open(my $input, '<', $lintian_log);
        while (<$input>) {
            if (
                m/^N: [ ] Processing [ ] (binary|udeb|source) [ ]
                       package [ ] (\S+) [ ] \(version [ ] (\S+), [ ]
                       arch [ ] (\S+)\)[ ]\.\.\./xsm
            ) {
                my ($type, $pkg, $ver, $arch) = ($1,$2, $3, $4);
                my $k = "$type:$pkg/$ver";
                $k .= "/$arch" if $type ne 'source';
                $copy_mode = 0;
                $copy_mode = 1 if exists($keep_filter->{$k});
            }
            if ($copy_mode) {
                if ($first) {
                    print {$new_fd} "N: ---start-of-old-lintian-log-file---\n";
                    $first = 0;
                }
                print {$new_fd} $_;
            }
        }
        close($input);
        close($new_fd);
        rename($tmp_path, $lintian_log);
    };
    if (my $err = $@) {
        # Unlink $new_lintian_log, we ignore errors as the one we
        # already got is more important/interesting.
        no autodie qw(unlink);
        unlink($tmp_path) or warn("Cannot unlink $tmp_path: $!");
        die($err);
    }
    return;
}

sub rewrite_lintian_log {
    my ($keep_filter) = @_;
    my $lintian_log_dir = $OPT{'lintian-log-dir'};
    my ($nfd, $new_lintian_log);

    ($nfd, $new_lintian_log)
      = tempfile('lintian.log-XXXXXXX', DIR => $lintian_log_dir);
    chmod(0644, $nfd);
    update_lintian_log($keep_filter, $nfd, $new_lintian_log);
    return 1;
}

sub usage {
    my $cmd = basename($0);
    my $me = "lintian $cmd";
    print <<EOF;
Internal command for the Lintian reporting framework
Usage: $me <args> -- <extra lintian args>

  --help                      Show this text and exit

  --lintian-frontend PROG     Use PROG as frontend for lintian (defaults to "lintian")
  --lintian-log-dir DIR       Path to the harness log dir. [!]
  --lintian-scratch-space DIR Use DIR for temporary files (notably temp labs)
  --schedule-chunk-size N     Run at most N groups in a given lintian run.
  --schedule-limit-groups N   Schedule at most N groups in total. [!]
  --state-dir DIR             Directory containing the state cache (must be
                              writable). [!]

Arguments marked with [!] are required for a successful run.
EOF

    exit(0);
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

