#!/usr/bin/perl
#
# Lintian reporting harness -- Create and maintain Lintian reports automatically
#
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

package reporting_harness;

use v5.20;
use warnings;
use utf8;

use constant BACKLOG_PROCESSING_GROUP_LIMIT => 1024;

use Date::Format qw(time2str);
use File::Copy;
use FileHandle;
use Getopt::Long;
use Path::Tiny;
use POSIX qw(strftime);
use YAML::XS ();

use Lintian::IO::Async qw(safe_qx);
use Lintian::Processable;
use Lintian::Relation::Version qw(versions_comparator);
use Lintian::Reporting::Util qw(load_state_cache save_state_cache);
use Lintian::Util qw(open_gz);

use constant EMPTY => q{};

sub usage {
    print <<END;
Lintian reporting harness
Create and maintain Lintian reports automatically

Usage: harness [ -i | -f | -r | -c ]

Options:
  -c         clean mode, erase everything and start from scratch (implies -f)
  -f         full mode, blithely overwrite lintian.log
  -i         incremental mode, use old lintian.log data, process changes only
  -r, --[no-]generate-reports
             Whether to generate reports.  By default, reports will be
             generated at the end of a run with -i, -f or -c.  It can also be
             used as a standard alone "mode", where only reports are
             regenerated.
  --reporting-config FILE
             Parse FILE as the primary configuration file.  Defines which
             archives to process, etc.  (Default: ./config.yaml)
  --dry-run  pretend to do the actions without actually doing them.  The
             "normal" harness output will go to stdout rather than the
             harness.log.
  --to-stdout
             [For debugging] Have output go to stdout as well as the usual
             log files.  Note, this option has no (extra) effect with --dry-run.
  --schedule-chunk-size N
             Schedule at most N groups in a given run of Lintian.  If more than N
             groups need to be processed, harness will invoke Lintian more than
             once.  If N is 0, schedule all groups in one go.  (Default: 512)
  --schedule-limit-groups N
             Schedule at most N groups in this run of harness.  If more than N
             groups need to be processed, harness leave the rest for a subsequent
             run.  (Default: ${\BACKLOG_PROCESSING_GROUP_LIMIT})

Incremental mode is the default if you have a lintian.log;
otherwise, it's full.

Report bugs to <lintian-maint\@debian.org>.
END
    #'/# for cperl-mode
    exit;
}

my %opt = (
    'schedule-chunk-size' => 512,
    'schedule-limit-groups' => BACKLOG_PROCESSING_GROUP_LIMIT,
    'reporting-config' => './config.yaml',
);

my %opthash = (
    'i' => \$opt{'incremental-mode'},
    'c' => \$opt{'clean-mode'},
    'f' => \$opt{'full-mode'},
    'generate-reports|r!' => \$opt{'generate-reports'},
    'reporting-config=s'=> \$opt{'reporting-config'},
    'dry-run' => \$opt{'dry-run'},
    'schedule-chunk-size=i' => \$opt{'schedule-chunk-size'},
    'schedule-limit-groups=i' => \$opt{'schedule-limit-groups'},
    'to-stdout' => \$opt{'to-stdout'},
    'help|h' => \&usage,
);

# Global variables
my (
    $log_file, $lintian_log, $lintian_perf_log,
    $html_reports_log,$sync_state_log, $lintian_cmd,
    $STATE_DIR, $LINTIAN_VERSION, $LOG_FD,
    $CONFIG,$LOG_DIR, $HTML_DIR,
    $HTML_TMP_DIR,$LINTIAN_SCRATCH_SPACE, $LINTIAN_BASE,
    $EXTRA_LINTIAN_OPTIONS,
);

sub required_cfg_value {
    my (@keys) = @_;
    my $v = $CONFIG;
    for my $key (@keys) {
        if (not exists($v->{$key})) {
            my $k = join('.', @keys);
            die("Missing required config parameter: ${k}\n");
        }
        $v = $v->{$key};
    }
    return $v;
}

sub required_cfg_list_value {
    my (@keys) = @_;
    my $v = required_cfg_value(@keys);
    if (not defined($v) or ref($v) ne 'ARRAY') {
        my $k = join('.', @keys);
        die("Invalid configuration: ${k} must be a (possibly empty) list\n");
    }
    return $v;
}

sub main {
    parse_options_and_config();

    # turn file buffering off
    STDOUT->autoflush;

    unless ($opt{'dry-run'}) {
        # rotate log files
        my @rotate_logs
          = ($log_file, $html_reports_log, $lintian_perf_log, $sync_state_log);
        safe_qx('savelog', @rotate_logs);

        # create new log file
        open($LOG_FD, '>', $log_file)
          or die("cannot open log file $log_file for writing: $!");
        $LOG_FD->autoflush;
    } else {
        $opt{'to-stdout'} = 0;
        open($LOG_FD, '>&', \*STDOUT)
          or die "Cannot open log file <stdout> for writing: $!";
        Log('Running in dry-run mode');
    }
    # From here on we can use Log() and Die().
    if (not $opt{'dry-run'} and $opt{'clean-mode'}) {
        Log('Purging old state-cache/dir');
        path($STATE_DIR)->remove_tree;
    }

    if (not -d $STATE_DIR) {
        path($STATE_DIR)->mkpath;
        Log("Created cache dir: $STATE_DIR");
    }

    if (   !$opt{'generate-reports'}
        && !$opt{'full-mode'}
        && !$opt{'incremental-mode'}) {
        # Nothing explicitly chosen, default to -i if the log is present,
        # otherwise -f.
        if (-f $lintian_log) {
            $opt{'incremental-mode'} = 1;
        } else {
            $opt{'full-mode'} = 1;
        }
    }

    # Default to yes, if not explicitly disabled.
    $opt{'generate-reports'} //= 1;

    if ($opt{'incremental-mode'} or $opt{'full-mode'}) {
        run_lintian();
    }

    if ($opt{'generate-reports'}) {
        generate_reports();
    }

    # ready!!! :-)
    Log('All done.');
    exit 0;
}

# -------------------------------

sub parse_options_and_config {

    # init commandline parser
    Getopt::Long::config('bundling', 'no_getopt_compat', 'no_auto_abbrev');

    # process commandline options
    GetOptions(%opthash)
      or die("error parsing options\n");

    # clean implies full - do this as early as possible, so we can just
    # check $opt{'full-mode'} rather than a full
    #   ($opt{'clean-mode'} || $opt{'full-mode'})
    $opt{'full-mode'} = 1 if $opt{'clean-mode'};

    die("Cannot use both incremental and full/clean.\n")
      if $opt{'incremental-mode'} && $opt{'full-mode'};
    die("The argument for --schedule-limit-groups must be an > 0\n")
      if $opt{'schedule-limit-groups'} < 1;
    if (not $opt{'reporting-config'} or not -f $opt{'reporting-config'}) {
        die("The --reporting-config parameter must point to an existing file\n"
        );
    }
    # read configuration
    $CONFIG = YAML::XS::LoadFile($opt{'reporting-config'});
    $LOG_DIR = required_cfg_value('storage', 'log-dir');
    $HTML_DIR = required_cfg_value('storage', 'reports-dir');
    $HTML_TMP_DIR = required_cfg_value('storage', 'reports-work-dir');
    $STATE_DIR = required_cfg_value('storage', 'state-cache');
    $LINTIAN_SCRATCH_SPACE = required_cfg_value('storage', 'scratch-space');

    if (   exists($CONFIG->{'lintian'})
        && exists($CONFIG->{'lintian'}{'extra-options'})) {
        $EXTRA_LINTIAN_OPTIONS
          = required_cfg_list_value('lintian', 'extra-options');
    } else {
        $EXTRA_LINTIAN_OPTIONS = [];
    }

    $LINTIAN_BASE = $ENV{'LINTIAN_BASE'};

    $lintian_cmd = "$LINTIAN_BASE/bin/lintian";

    $LINTIAN_VERSION= safe_qx("$LINTIAN_BASE/bin/lintian",'--print-version');
    chomp($LINTIAN_VERSION);

    (
        $log_file, $lintian_log, $lintian_perf_log,$html_reports_log,
        $sync_state_log
      )
      = map {"$LOG_DIR/$_" }
      qw(harness.log lintian.log lintian-perf.log html_reports.log sync_state.log);

    return;
}

sub run_lintian {
    my @sync_state_args = (
        '--reporting-config', $opt{'reporting-config'},
        '--desired-version', $LINTIAN_VERSION,'--debug',
    );
    my @lintian_harness_args = (
        '--lintian-frontend', "$LINTIAN_BASE/bin/lintian",
        '--lintian-log-dir', $LOG_DIR,
        '--schedule-chunk-size', $opt{'schedule-chunk-size'},
        '--schedule-limit-groups', $opt{'schedule-limit-groups'},
        '--state-dir', $STATE_DIR,
        # Finish with the lintian command-line
        '--', @{$EXTRA_LINTIAN_OPTIONS});

    if ($opt{'full-mode'}) {
        push(@sync_state_args, '--reschedule-all');
    }
    if ($opt{'dry-run'}) {
        push(@sync_state_args, '--dry-run');
    }

    if ($LINTIAN_SCRATCH_SPACE) {
        unshift(@lintian_harness_args,
            '--lintian-scratch-space', $LINTIAN_SCRATCH_SPACE);
    }

    Log('Updating harness state cache (reading mirror index files)');

    my $loop = IO::Async::Loop->new;
    my $syncdone = $loop->new_future;

    my @synccommand = ($lintian_cmd, 'reporting-sync-state', @sync_state_args);
    Log('Command: ' . join(' ', @synccommand));

    my $syncprocess = IO::Async::Process->new(
        command => [@synccommand],
        stdout => { via => 'pipe_read' },
        stderr => { via => 'pipe_read' },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            if ($status) {
                Log("warning: executing reporting-sync-state returned $status"
                );
                my $message= "Non-zero status $status from @synccommand";
                $syncdone->fail($message);
                return;
            }

            $syncdone->done("Done with @synccommand");
            return;
        });

    my $syncfh = *STDOUT;
    unless($opt{'dry-run'}) {
        open($syncfh, '>', $sync_state_log)
          or die "Could not open file '$sync_state_log': $!";
    }

    $syncprocess->stdout->configure(
        on_read => sub {
            my ($stream, $buffref, $eof) = @_;

            if (length $$buffref) {
                print {$syncfh} $$buffref;
                $$buffref = EMPTY;
            }

            if ($eof) {
                close($syncfh)
                  unless $opt{'dry-run'};
            }

            return 0;
        },
    );

    $syncprocess->stderr->configure(
        on_read => sub {
            my ($stream, $buffref, $eof) = @_;

            if (length $$buffref) {
                print STDERR $$buffref;
                $$buffref = EMPTY;
            }

            return 0;
        },
    );

    $loop->add($syncprocess);
    $syncdone->await;

    Log('Running lintian (via reporting-lintian-harness)');
    Log(
        'Command: '
          . join(' ',
            $lintian_cmd, 'reporting-lintian-harness',@lintian_harness_args));
    my %harness_lintian_opts = (
        'pipe_out'  => FileHandle->new,
        'err'       => '&1',
        'fail'      => 'never',
    );

    if (not $opt{'dry-run'}) {
        spawn(\%harness_lintian_opts,
            [$lintian_cmd, 'reporting-lintian-harness', @lintian_harness_args]
        );
        my $child_out = $harness_lintian_opts{'pipe_out'};
        while (my $line = <$child_out>) {
            chomp($line);
            Log_no_ts($line);
        }
        close($child_out);
        if (not reap(\%harness_lintian_opts)) {
            my $exit_code = $harness_lintian_opts{harness}->full_result;
            my $res = ($exit_code >> 8) & 0xff;
            my $sig = $exit_code & 0xff;
            # Exit code 2 is "time-out", 3 is "lintian got signalled"
            # 255 => reporting-lintian-harness caught an unhandled trappable
            # error.
            if ($res) {
                if ($res == 255) {
                    Die('Lintian harness died with an unhandled exception');
                } elsif ($res == 3) {
                    Log('Lintian harness stopped early due to signal');
                    if ($opt{'generate-reports'}) {
                        Log('Skipping report generation');
                        $opt{'generate-reports'} = 0;
                    }
                } elsif ($res != 2) {
                    Die("Lintian harness terminated with code $res");
                }
            } elsif ($sig) {
                Die("Lintian harness was killed by signal $sig");
            }
        }
    }
    return;
}

sub generate_reports {
    my @html_reports_args
      = ('--reporting-config',$opt{'reporting-config'},$lintian_log,);
    # create html reports
    Log('Creating HTML reports...');
    Log("Executing $lintian_cmd reporting-html-reports @html_reports_args");

    my $loop = IO::Async::Loop->new;
    my $htmldone = $loop->new_future;

    my @htmlcommand
      = ($lintian_cmd, 'reporting-html-reports', @html_reports_args);
    my $htmlprocess = IO::Async::Process->new(
        command => [@htmlcommand],
        stdout => { via => 'pipe_read' },
        stderr => { via => 'pipe_read' },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            if ($status) {
                Log(
"warning: executing reporting-html-reports returned $status"
                );
                my $message= "Non-zero status $status from @htmlcommand";
                $htmldone->fail($message);
                return;
            }

            $htmldone->done("Done with @htmlcommand");
            return;
        });

    open(my $htmlfh, '>', $html_reports_log)
      or die "Could not open file '$html_reports_log': $!";

    $htmlprocess->stdout->configure(
        on_read => sub {
            my ($stream, $buffref, $eof) = @_;

            if (length $$buffref) {
                print {$htmlfh} $$buffref;
                $$buffref = EMPTY;
            }

            close($htmlfh)
              if $eof;

            return 0;
        },
    );

    $htmlprocess->stderr->configure(
        on_read => sub {
            my ($stream, $buffref, $eof) = @_;

            if (length $$buffref) {
                print STDERR $$buffref;
                $$buffref = EMPTY;
            }

            return 0;
        },
    );

    $loop->add($htmlprocess);
    $htmldone->await;

    Log('');

    # rotate the statistics file updated by reporting-html-reports
    if (!$opt{'dry-run'} && -f "$STATE_DIR/statistics") {
        my $date = time2str('%Y%m%d', time());
        my $dest = "$LOG_DIR/stats/statistics-${date}";
        copy("$STATE_DIR/statistics", $dest)
          or Log('warning: could not rotate the statistics file');
    }

    # install new html directory
    Log('Installing HTML reports...');
    unless ($opt{'dry-run'}) {
        path($HTML_DIR)->remove_tree;
        # a tiny bit of race right here
        rename($HTML_TMP_DIR,$HTML_DIR)
          or Die("error renaming $HTML_TMP_DIR into $HTML_DIR");
    }
    Log('');
    return;
}

sub Log {
    my ($msg) = @_;
    my $ts = strftime('[%FT%T]', localtime());
    Log_no_ts("${ts}: ${msg}");
    return;
}

sub Log_no_ts {
    my ($msg) = @_;
    print {$LOG_FD} $msg,"\n";
    print $msg, "\n" if $opt{'to-stdout'};
    return;
}

sub Die {
    Log("fatal error: $_[0]");
    exit 1;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
