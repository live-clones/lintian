#!/usr/bin/perl -w
# {{{ Legal stuff
# Lintian -- Debian package checker
#
# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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
# }}}

# {{{ libraries and such
no lib '.';

use strict;
use warnings;
use autodie;
use utf8;
use v5.16;

use Cwd qw(abs_path);
use Carp qw(verbose);
use Getopt::Long();
use List::MoreUtils qw(any none);
use Path::Tiny;
use POSIX qw(:sys_wait_h);

my $INIT_ROOT = $ENV{'LINTIAN_ROOT'};

use Lintian::Data;
use Lintian::Inspect::Changelog;
use Lintian::Internal::FrontendUtil
  qw(default_parallel sanitize_environment open_file_or_fd);
use Lintian::Output::Standard;
use Lintian::Pool;
use Lintian::Profile;
use Lintian::Tags;
use Lintian::Util qw(internal_error parse_boolean strip safe_qx);

# only in GNOME; need original environment
my $interactive = -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT));
my $hyperlinks_capable = $interactive && qx{env | fgrep -i gnome};

sanitize_environment();

# }}}

# {{{ Application Variables

# Environment variables Lintian cares about - the list contains
# the ones that can also be set via the config file
#
# %opt (defined below) will be updated with values of the env
# after parsing cmd-line options.  A given value in %opt is
# updated to use the ENV variable if the one in %opt is undef
# and ENV has a value.
#
# NB: Variables listed here are not always exported.
#
# CAVEAT: If it does not start with "LINTIAN_", then it should
# probably be listed in %PRESERVE_ENV in
# L::Internal::FrontendUtil (!)
my @ENV_VARS = (
    # LINTIAN_CFG  - handled manually
    qw(
      LINTIAN_PROFILE
      TMPDIR
      ));

### "Normal" application variables
my %conf_opt;                   #names of options set in the cfg file
my %opt = (                     #hash of some flags from cmd or cfg
     # Init some cmd-line value defaults
    'debug'             => 0,
    'jobs'              => default_parallel(),
);

my $experimental_output_opts;

my (@CLOSE_AT_END, $TAGS);
my $OUTPUT = Lintian::Output::Standard->new;
my @certainties = qw(wild-guess possible certain);
my (@display_level, %display_source, %suppress_tags);
my ($action, $checks, $check_tags, $dont_check, $received_signal);
my @unpack_info;
my $user_dirs = $ENV{'LINTIAN_ENABLE_USER_DIRS'} // 1;
my $exit_code = 0;
my $STATUS_FD;

# }}}

# {{{ Setup Code

sub lintian_banner {
    my $lintian_version = dplint::lintian_version();
    return "Lintian v${lintian_version}";
}

sub fatal_error {
    my ($msg) = @_;
    $msg =~ s/ at .*//;
    print STDERR  "$msg\n";
    exit(2);
}

# }}}

# {{{ Process Command Line

#######################################
# Subroutines called by various options
# in the options hash below.  These are
# invoked to process the commandline
# options
#######################################
# Display Command Syntax
# Options: -h|--help
sub syntax {
    my (undef, $value) = @_;
    my $show_extended = 0;
    my $banner = lintian_banner();
    if ($value) {
        if ($value eq 'extended' or $value eq 'all') {
            $show_extended = 1;
        } else {
            warn "warning: Ignoring unknown value for --help\n";
            $value = '';
        }
    }

    print "${banner}\n";
    print <<"EOT-EOT-EOT";
Syntax: lintian [action] [options] [--] [packages] ...
Actions:
    -c, --check               check packages (default action)
    -C X, --check-part X      check only certain aspects
    -F, --ftp-master-rejects  only check for automatic reject tags
    -T X, --tags X            only run checks needed for requested tags
    --tags-from-file X        like --tags, but read list from file
    -u, --unpack              only unpack packages in the lab
    -X X, --dont-check-part X don\'t check certain aspects
General options:
    -h, --help                display short help text
    --print-version           print unadorned version number and exit
    -q, --quiet               suppress all informational messages
    -v, --verbose             verbose messages
    -V, --version             display Lintian version and exit
Behavior options:
    --color never/always/auto disable, enable, or enable color for TTY
    --hyperlinks on/off       hyperlinks for TTY (when supported)
    --default-display-level   reset the display level to the default
    --display-source X        restrict displayed tags by source
    -E, --display-experimental display "X:" tags (normally suppressed)
    --no-display-experimental suppress "X:" tags
    -i, --info                give detailed info about tags
    -I, --display-info        display "I:" tags (normally suppressed)
    -L, --display-level       display tags with the specified level
    -o, --no-override         ignore overrides
    --pedantic                display "P:" tags (normally suppressed)
    --profile X               Use the profile X or use vendor X checks
    --show-overrides          output tags that have been overridden
    --hide-overrides          do not output tags that have been overridden (default)
    --suppress-tags T,...     don\'t show the specified tags
    --suppress-tags-from-file X don\'t show the tags listed in file X
EOT-EOT-EOT
    if ($show_extended) {
        # Not a special option per se, but most people will probably
        # not need it
        print <<"EOT-EOT-EOT";
    --tag-display-limit X     Specify "tag per package" display limit
    --no-tag-display-limit    Disable "tag per package" display limit
                              (equivalent to --tag-display-limit=0)
EOT-EOT-EOT
    }

    print <<"EOT-EOT-EOT";
Configuration options:
    --cfg CONFIGFILE          read CONFIGFILE for configuration
    --no-cfg                  do not read any config files
    --ignore-lintian-env      ignore LINTIAN_* env variables
    --include-dir DIR         include checks, libraries (etc.) from DIR (*)
    -j X, --jobs X            limit the number of parallel unpacking jobs to X
    --[no-]user-dirs          whether to use files from user directories (*)
EOT-EOT-EOT

    if ($show_extended) {
        print <<"EOT-EOT-EOT";
Developer/Special usage options:
    --allow-root              suppress lintian\'s warning when run as root
    -d, --debug               turn Lintian\'s debug messages on (repeatable)
    --keep-lab                keep lab after run
    --packages-from-file  X   process the packages in a file (if "-" use stdin)
    --perf-debug              turn on performance debugging
    --perf-output X           send performance logging to file (or fd w. \&X)
    --status-log X            send status logging to file (or fd w. \&X) [internal use only]
    -U X, --unpack-info X     specify which info should be collected
EOT-EOT-EOT
    }

    print <<"EOT-EOT-EOT";

Options marked with (*) should be the first options if given at all.
EOT-EOT-EOT

    if (not $show_extended) {
        print <<"EOT-EOT-EOT";

Note that some options have been omitted, use "--help=extended" to see them
all.
EOT-EOT-EOT
    }

    exit 0;
}

# Display Version Banner
# Options: -V|--version, --print-version
sub banner {
    if ($_[0] eq 'print-version') {
        my $lintian_version = dplint::lintian_version();
        print "${lintian_version}\n";
    } else {
        my $banner = lintian_banner();
        print "${banner}\n";
    }
    exit 0;
}

# Record action requested
# Options: -S, -R, -c, -u, -r
sub record_action {
    if ($action) {
        fatal_error("too many actions specified: $_[0]");
    }
    $action = "$_[0]";
    return;
}

# Record Parts requested for checking
# Options: -C|--check-part
sub record_check_part {
    if (defined $action and $action eq 'check' and $checks) {
        fatal_error('multiple -C or --check-part options not allowed');
    }
    if ($dont_check) {
        fatal_error(
            join(q{ },
                'both -C or --check-part and -X',
                'or --dont-check-part options not allowed'));
    }
    record_action('check');
    $checks = "$_[1]";
    return;
}

# Record Parts requested for checking
# Options: -T|--tags
sub record_check_tags {
    if (defined $action and $action eq 'check' and $check_tags) {
        fatal_error('multiple -T or --tags options not allowed');
    }
    if ($checks) {
        fatal_error(
            'both -T or --tags and -C or --check-part options not allowed');
    }
    if ($dont_check) {
        fatal_error(
            'both -T or --tags and -X or --dont-check-part options not allowed'
        );
    }
    record_action('check');
    $check_tags = "$_[1]";
    return;
}

# Record Parts requested for checking
# Options: --tags-from-file
sub record_check_tags_from_file {
    my ($option, $name) = @_;
    open(my $file, '<', $name);
    my @tags;
    for my $line (<$file>) {
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next unless $line;
        next if $line =~ /^\#/;
        push(@tags, split(/\s*,\s*/, $line));
    }
    close($file);
    return record_check_tags($option, join(',', @tags));
}

# Record tags that should be suppressed.
# Options: --suppress-tags
sub record_suppress_tags {
    my ($option, $tags) = @_;
    for my $tag (split(/\s*,\s*/, $tags)) {
        $suppress_tags{$tag} = 1;
    }
    return;
}

# Record tags that should be suppressed from a file.
# Options: --suppress-tags-from-file
sub record_suppress_tags_from_file {
    my ($option, $name) = @_;
    open(my $file, '<', $name);
    for my $line (<$file>) {
        chomp $line;
        $line =~ s/^\s+//;
        # Remove trailing white-space/comments
        $line =~ s/(\#.*+|\s+)$//;
        next unless $line;
        record_suppress_tags($option, $line);
    }
    close($file);
    return;
}

# Record Parts requested not to check
# Options: -X|--dont-check-part X
sub record_dont_check_part {
    if (defined $action and $action eq 'check' and $dont_check) {
        fatal_error('multiple -X or --dont-check-part options not allowed');
    }
    if ($checks) {
        fatal_error(
            join(q{ },
                'both -C or --check-part and',
                '-X or --dont-check-part options not allowed'));
    }
    record_action('check');
    $dont_check = "$_[1]";
    return;
}

# Process -L|--display-level flag
sub record_display_level {
    my ($option, $level) = @_;
    my ($op, $rel);
    if ($level =~ s/^([+=-])//) {
        $op = $1;
    }
    if ($level =~ s/^([<>]=?|=)//) {
        $rel = $1;
    }
    my ($severity, $certainty) = split('/', $level);
    $op = '=' unless defined $op;
    $rel = '=' unless defined $rel;
    if (not defined $certainty) {
        if (any { $severity eq $_ } @certainties) {
            $certainty = $severity;
            undef $severity;
        }
    }
    push(@display_level, [$op, $rel, $severity, $certainty]);
    return;
}

# Process -I|--display-info flag
sub display_infotags {
    push(@display_level, ['+', '>=', 'wishlist']);
    return;
}

# Process --pedantic flag
sub display_pedantictags {
    push(@display_level, ['+', '=', 'pedantic']);
    return;
}

sub display_classificationtags {
    push(@display_level, ['+', '=', 'classification']);
    return;
}

# Process --default-display-level flag
sub default_display_level {
    push(@display_level,
        ['=', '>=', 'important'],
        ['+', '>=', 'normal', 'possible'],
        ['+', '>=', 'minor', 'certain'],
    );
    return;
}

# Process --display-source flag
sub record_display_source {
    $display_source{$_[1]} = 1;
    return;
}

# Process -q|--quite flag
sub record_quiet {
    $opt{'verbose'} = -1;
    return;
}

sub record_option_too_late {
    fatal_error(
        join(q{ },
            'Warning: --include-dir and --[no-]user-dirs',
            'should be the first option(s) if given'));
}

# Process display-info and display-level options in cfg files
#  - dies if display-info and display-level are used together
#  - adds the relevant display level unless the command-line
#    added something to it.
#  - uses @display_level to track cmd-line appearances of
#    --display-level/--display-info
sub cfg_display_level {
    my ($var, $val) = @_;
    if ($var eq 'display-info' or $var eq 'pedantic'){
        fatal_error(
            "$var and display-level may not both appear in the config file.\n")
          if $conf_opt{'display-level'};

        return unless $val; # case "display-info=no" (or "pedantic=no")

        # We are only supposed to modify @display_level if it was not
        # set by a command-line option.  However, both display-info
        # and pedantic comes here so we cannot determine this solely
        # by checking if @display_level is empty.  We use
        # "__conf-display-opts" to determine if @display_level was set
        # by a conf option or not.
        return if @display_level && !$conf_opt{'__conf-display-opts'};

        $conf_opt{'__conf-display-opts'} = 1;
        display_infotags() if $var eq 'display-info';
        display_pedantictags() if $var eq 'pedantic';
    } elsif ($var eq 'display-level'){
        foreach my $other (qw(pedantic display-info)) {
            fatal_error(
                join(q{ },
                    "$other and display-level may not",
                    'both appear in the config file.'))if $conf_opt{$other};
        }

        return if @display_level;
        strip($val);
        foreach my $dl (split m/\s++/, $val) {
            record_display_level('display-level', $dl);
        }
    }
    return;
}

# Processes quiet and verbose options in cfg files.
# - dies if quiet and verbose are used together
# - sets the verbosity level ($opt{'verbose'}) unless
#   already set.
sub cfg_verbosity {
    my ($var, $val) = @_;
    if (   ($var eq 'verbose' && exists $conf_opt{'quiet'})
        || ($var eq 'quiet' && exists $conf_opt{'verbose'})) {
        fatal_error(
            'verbose and quiet may not both appear in the config file.');
    }
    # quiet = no or verbose = no => no change
    return unless $val;
    # Do not change the value if set by command line.
    return if defined $opt{'verbose'};
    # quiet = yes => verbosity_level = -1
    #
    # technically this allows you to enable verbose by using "quiet =
    # -1" (etc.), but most people will probably not use this
    # "feature".
    $val = -$val if $var eq 'quiet';
    $opt{'verbose'} = $val;
    return;
}

# Process overrides option in the cfg files
sub cfg_override {
    my ($var, $val) = @_;
    return if defined $opt{'no-override'};
    # This option is inverted in the config file
    $opt{'no-override'} = !$val;
    return;
}

# Hash used to process commandline options
my %opthash = (
    # ------------------ actions
    'check|c' => \&record_action,
    'check-part|C=s' => \&record_check_part,
    'tags|T=s' => \&record_check_tags,
    'tags-from-file=s' => \&record_check_tags_from_file,
    'ftp-master-rejects|F' => \$opt{'ftp-master-rejects'},
    'dont-check-part|X=s' => \&record_dont_check_part,
    'unpack|u' => \&record_action,

    # ------------------ general options
    'help|h:s' => \&syntax,
    'version|V' => \&banner,
    'print-version' => \&banner,

    'verbose|v' => \$opt{'verbose'},
    'debug|d+' => \$opt{'debug'}, # Count the -d flags
    'quiet|q' => \&record_quiet, # sets $opt{'verbose'} to -1
    'perf-debug' => \$opt{'perf-debug'},
    'perf-output=s' => \$opt{'perf-output'},
    'status-log=s' => \$opt{'status-log'},

    # ------------------ behaviour options
    'info|i' => \$opt{'info'},
    'display-info|I' => \&display_infotags,
    'display-experimental|E!' => \$opt{'display-experimental'},
    'pedantic' => \&display_pedantictags,
    'display-level|L=s' => \&record_display_level,
    'default-display-level' => \&default_display_level,
    'display-source=s' => \&record_display_source,
    'suppress-tags=s' => \&record_suppress_tags,
    'suppress-tags-from-file=s' => \&record_suppress_tags_from_file,
    'no-override|o' => \$opt{'no-override'},
    'show-overrides' => \$opt{'show-overrides'},
    'hide-overrides' => sub { $opt{'show-overrides'} = 0; },
    'color=s' => \$opt{'color'},
    'hyperlinks=s' => \$opt{'hyperlinks'},
    'unpack-info|U=s' => \@unpack_info,
    'allow-root' => \$opt{'allow-root'},
    'keep-lab' => \$opt{'keep-lab'},
    'no-tag-display-limit' => sub { $opt{'tag-display-limit'} = 0; },
    'tag-display-limit=i' => \$opt{'tag-display-limit'},

    # ------------------ configuration options
    'cfg=s' => \$opt{'LINTIAN_CFG'},
    'no-cfg' => \$opt{'no-cfg'},
    'profile=s' => \$opt{'LINTIAN_PROFILE'},

    'jobs|j=i' => \$opt{'jobs'},
    'ignore-lintian-env' => \$opt{'ignore-lintian-env'},
    'include-dir=s' => \&record_option_too_late,
    'user-dirs!' => \&record_option_too_late,

    # ------------------ package selection options
    'packages-from-file=s' => \$opt{'packages-from-file'},

    # ------------------ experimental
    'exp-output:s' => \$experimental_output_opts,
);

# dplint has a similar wrapper; but it uses a different exit code
# for uncaught exceptions (compared to what lintian documents).
sub _main {
    eval {_main();};
    # Cocerce the error to a string
    if (my $err = "$@") {
        $err =~ s/\n//;
        # Special-case the message from the signal handler as it is not
        # entirely unexpected.
        if ($err eq 'N: Interrupted') {
            fatal_error($err);
        }
        print STDERR "$err\n";
        fatal_error('Uncaught exception');
    }
    fatal_error('Assertion error: _main returned !?');
}

sub main {

    $0 = join(' ', $0, @ARGV);

    #turn off file buffering
    STDOUT->autoflush;
    binmode(STDOUT, ':utf8');

    # Globally ignore SIGPIPE.  We'd rather deal with error returns from write
    # than randomly delivered signals.
    $SIG{PIPE} = 'IGNORE';

    parse_options();

    # environment variables override settings in conf file, so load them now
    # assuming they were not set by cmd-line options
    foreach my $var (@ENV_VARS) {
     # note $opt{$var} will usually always exists due to the call to GetOptions
     # so we have to use "defined" here
        $opt{$var} = $ENV{$var} if $ENV{$var} && !defined $opt{$var};
    }

    # Check if we should load a config file
    if ($opt{'no-cfg'}) {
        $opt{'LINTIAN_CFG'} = '';
    } else {
        if (not $opt{'LINTIAN_CFG'}) {
            $opt{'LINTIAN_CFG'} = _find_cfg_file();
        }
        # _find_cfg_file() can return undef
        if ($opt{'LINTIAN_CFG'}) {
            parse_config_file($opt{'LINTIAN_CFG'});
        }
        $opt{'LINTIAN_CFG'} //= '';
    }

    $ENV{'TMPDIR'} = $opt{'TMPDIR'} if defined($opt{'TMPDIR'});

    if (defined $experimental_output_opts) {
        my %opts = map { split(/=/) } split(/,/, $experimental_output_opts);
        foreach (keys %opts) {
            if ($_ eq 'format') {
                if ($opts{$_} eq 'colons') {
                    require Lintian::Output::ColonSeparated;
                    $OUTPUT= Lintian::Output::ColonSeparated->new;
                } elsif ($opts{$_} eq 'letterqualifier') {
                    require Lintian::Output::LetterQualifier;
                    $OUTPUT= Lintian::Output::LetterQualifier->new;
                } elsif ($opts{$_} eq 'xml') {
                    require Lintian::Output::XML;
                    $OUTPUT = Lintian::Output::XML->new;
                } elsif ($opts{$_} eq 'fullewi') {
                    require Lintian::Output::FullEWI;
                    $OUTPUT = Lintian::Output::FullEWI->new;
                } elsif ($opts{$_} eq 'universal') {
                    require Lintian::Output::Universal;
                    $OUTPUT = Lintian::Output::Universal->new;
                }
            }
        }
    }

    # check permitted values for --color / color
    #  - We set the default to 'auto' here; because we cannot do
    #    it before the config check.
    $opt{'color'} = 'auto' unless defined($opt{'color'});
    if ($opt{'color'} and $opt{'color'} !~ /^(?:never|always|auto|html)$/) {
        fatal_error(
            join(q{ },
                'The color value must be one of',
                'never", "always", "auto" or "html"'));
    }

    if ($opt{'color'} eq 'never') {
        $opt{'hyperlinks'} //= 'off';
    } else {
        $opt{'hyperlinks'} //= 'on';
    }
    fatal_error('The hyperlink value must be one of "on" or "off"')
      unless $opt{'hyperlinks'} =~ /^(?:on|off)$/;

    if ($opt{'verbose'} || !-t STDOUT) {
        $opt{'tag-display-limit'} //= 0;
    } else {
        $opt{'tag-display-limit'} //= 4;
    }

    if ($opt{'debug'}) {
        $opt{'verbose'} = 1;
        $ENV{'LINTIAN_DEBUG'} = $opt{'debug'};
        $SIG{__DIE__} = sub { Carp::confess(@_) };
    } else {
        # Ensure verbose has a defined value
        $opt{'verbose'} //= 0;
    }

    $OUTPUT->verbosity_level($opt{'verbose'});
    $OUTPUT->debug($opt{'debug'});

    $OUTPUT->color($opt{'color'});
    $OUTPUT->tty_hyperlinks($hyperlinks_capable&& $opt{hyperlinks} eq 'on');
    $OUTPUT->tag_display_limit($opt{'tag-display-limit'});
    $OUTPUT->showdescription($opt{'info'});

    $OUTPUT->perf_debug($opt{'perf-debug'});
    if (defined(my $perf_log = $opt{'perf-output'})) {
        my $fd = open_file_or_fd($perf_log, '>');
        $OUTPUT->perf_log_fd($fd);

        push(@CLOSE_AT_END, [$fd, $perf_log]);
    }

    if (defined(my $status_log = $opt{'status-log'})) {
        $STATUS_FD = open_file_or_fd($status_log, '>');
        $STATUS_FD->autoflush;

        push(@CLOSE_AT_END, [$STATUS_FD, $status_log]);
    } else {
        open($STATUS_FD, '>', '/dev/null');
    }

    # check for arguments
    if (    $action =~ /^(?:check|unpack)$/
        and $#ARGV == -1
        and not $opt{'packages-from-file'}) {
        my $ok = 0;
        # If debian/changelog exists, assume an implied
        # "../<source>_<version>_<arch>.changes" (or
        # "../<source>_<version>_source.changes").
        if (-f 'debian/changelog') {
            my $file = _find_changes();
            push @ARGV, $file;
            $ok = 1;
        }
        syntax() unless $ok;
    }

    if ($opt{'debug'}) {
        my $banner = lintian_banner();
        # Print Debug banner, now that we're finished determining
        # the values and have Lintian::Output available
        $OUTPUT->debug_msg(
            1,$banner,
            "Lintian root directory: $INIT_ROOT",
            "Configuration file: $opt{'LINTIAN_CFG'}",
            'UTF-8: ✓ (☃)',
            $OUTPUT->delimiter,
        );
    }

    my $PROFILE = eval { dplint::load_profile($opt{'LINTIAN_PROFILE'}); };
    fatal_error($@) if $@;

    # Ensure $opt{'LINTIAN_PROFILE'} is defined
    $opt{'LINTIAN_PROFILE'} = $PROFILE->name
      unless defined($opt{'LINTIAN_PROFILE'});
    $OUTPUT->v_msg('Using profile ' . $PROFILE->name . '.');
    Lintian::Data->set_vendor($PROFILE);

    $TAGS = Lintian::Tags->new;
    $TAGS->show_experimental($opt{'display-experimental'});
    $TAGS->show_overrides($opt{'show-overrides'});
    $TAGS->sources(keys(%display_source)) if %display_source;
    $TAGS->profile($PROFILE);

    if ($dont_check || %suppress_tags || $checks || $check_tags) {
        _update_profile($PROFILE, $TAGS, $dont_check, \%suppress_tags,$checks);
    }

    # Initialize display level settings.
    for my $level (@display_level) {
        eval { $TAGS->display(@{$level}) };
        fatal_error($@) if $@;
    }

    $SIG{'TERM'} = \&interrupted;
    $SIG{'INT'} = \&interrupted;
    $SIG{'QUIT'} = \&interrupted;

    #######################################
    #  Check for non deb specific actions
    if (
        not(   ($action eq 'unpack')
            or ($action eq 'check'))
    ) {
        fatal_error("invalid action $action specified");
    }

    my @subjects;
    push(@subjects, @ARGV);

    if ($opt{'packages-from-file'}){
        my $fd = open_file_or_fd($opt{'packages-from-file'}, '<');

        while (my $line = <$fd>) {
            chomp $line;

            next
              if $line =~ /^\s*$/;

            push(@subjects, $line);
        }

        # close unless it is STDIN (else we will see a lot of warnings
        # about STDIN being reopened as "output only")
        close($fd)
          unless fileno($fd) == fileno(STDIN);
    }

    my $pool = Lintian::Pool->new;

    for my $path (@subjects) {

        fatal_error
"bad package file name $path (neither .deb, .udeb, .changes, .dsc or .buildinfo file)"
          unless -f $path
          && $path =~ m/\.(?:u?deb|dsc|changes|buildinfo)$/;

        my $absolute = Cwd::abs_path($path);
        die "Cannot resolve $path: $!"
          unless $absolute;

        eval {
            # create a new group
            my $group = Lintian::Group->new;
            $group->pooldir($pool->basedir);
            $group->init_from_file($absolute);

            $pool->add_group($group);
        };
        if ($@) {
            print STDERR "Skipping $path: $@";
            $exit_code = 2;
        }
    }

    if ($pool->empty) {
        $OUTPUT->v_msg('No packages selected.');
        exit $exit_code;
    }

    $ENV{INIT_ROOT} = $INIT_ROOT;

    $pool->process($action, $PROFILE,$TAGS,\$exit_code, \%opt,
        $STATUS_FD, \@unpack_info, $OUTPUT);

    retrigger_signal()
      if $received_signal;

    # }}}

    exit $exit_code;
}

# {{{ Some subroutines

sub _find_cfg_file {
    return $ENV{'LINTIAN_CFG'}
      if exists $ENV{'LINTIAN_CFG'} and -f $ENV{'LINTIAN_CFG'};

    if ($user_dirs) {
        my $rcfile;
        {
            # File::BaseDir spews warnings if $ENV{'HOME'} is undef, so
            # make sure it is defined when we load the module.  Though,
            # we need to scope this, so $ENV{HOME} becomes undef again
            # when we check for it later.
            local $ENV{'HOME'} = $ENV{'HOME'} // '/nonexistent';
            require File::BaseDir;
            File::BaseDir->import(qw(config_home config_files));
        };
        # only accept config_home if either HOME or
        # XDG_CONFIG_HOME was set.  If both are unset, then this
        # will return the "bogus" path
        # "/nonexistent/lintian/lintianrc" and we don't want that
        # (in the however unlikely case that file actually
        # exists).
        $rcfile = config_home('lintian/lintianrc')
          if exists $ENV{'HOME'}
          or exists $ENV{'XDG_CONFIG_HOME'};
        return $rcfile if defined $rcfile and -f $rcfile;
        if (exists $ENV{'HOME'}) {
            $rcfile = $ENV{'HOME'} . '/.lintianrc';
            return $rcfile if -f $rcfile;
        }
        return '/etc/lintianrc' if -f '/etc/lintianrc';
        # config_files checks that the file exists for us
        $rcfile = config_files('lintian/lintianrc');
        return $rcfile if defined $rcfile and $rcfile ne '';

    }

    return; # None found
}

sub parse_config_file {
    my ($config_file) = @_;

    # Options that can appear in the config file
    my %cfghash = (
        'color'                => \$opt{'color'},
        'hyperlinks'           => \$opt{'hyperlinks'},
        'display-experimental' => \$opt{'display-experimental'},
        'display-info'         => \&cfg_display_level,
        'display-level'        => \&cfg_display_level,
        'info'                 => \$opt{'info'},
        'jobs'                 => \$opt{'jobs'},
        'pedantic'             => \&cfg_display_level,
        'quiet'                => \&cfg_verbosity,
        'override'             => \&cfg_override,
        'show-overrides'       => \$opt{'show-overrides'},
        'suppress-tags'        => \&record_suppress_tags,
        'suppress-tags-from-file' => \&record_suppress_tags_from_file,
        'tag-display-limit'    => \$opt{'tag-display-limit'},
        'verbose'              => \&cfg_verbosity,
    );

    open(my $fd, '<', $config_file);
    while (<$fd>) {
        chomp;
        s/\#.*$//go;
        s/\"//go;
        next if m/^\s*$/o;

        # substitute some special variables
        s,\$HOME/,$ENV{'HOME'}/,go;
        s,\~/,$ENV{'HOME'}/,go;

        my $found = 0;
        foreach my $var (@ENV_VARS) {
            if (m/^\s*$var\s*=\s*(.*\S)\s*$/i) {
                if (exists $conf_opt{$var}){
                    print STDERR
                      "Configuration variable $var appears more than once\n";
                    print STDERR " in $opt{'LINTIAN_CFG'} (line: $.)",
                      " - Using the first value!\n";
                    next;
                }
                $opt{$var} = $1 unless defined $opt{$var};
                $conf_opt{$var} = 1;
                $found = 1;
                last;
            }
        }
        unless ($found) {
            # check if it is a config option
            if (m/^\s*([-a-z]+)\s*=\s*(.*\S)\s*$/o){
                my ($var, $val) = ($1, $2);
                my $ref = $cfghash{$var};
                fatal_error(
                    "Unknown configuration variable $var at line: ${.}.")
                  unless $ref;
                if (exists $conf_opt{$var}){
                    print STDERR
                      "Configuration variable $var appears more than once\n";
                    print STDERR " in $opt{'LINTIAN_CFG'} (line: $.)",
                      " - Using the first value!\n";
                    next;
                }
                $conf_opt{$var} = 1;
                $found = 1;
                # Translate boolean strings to "0" or "1"; ignore
                # errors as not all values are (intended to be)
                # booleans.
                if (none { $var eq $_ } qw(jobs tag-display-limit)) {
                    eval { $val = parse_boolean($val); };
                }
                if (ref $ref eq 'SCALAR'){
                    # Check it was already set
                    next if defined $$ref;
                    $$ref = $val;
                } elsif (ref $ref eq 'CODE'){
                    $ref->($var, $val);
                }

            }
        }
        unless ($found) {
            fatal_error("syntax error in configuration file: $_");
        }
    }
    close($fd);
    return;
}

sub _find_changes {
    my $contents = path('debian/changelog')->slurp;
    my $changelog = Lintian::Inspect::Changelog->new;
    $changelog->parse($contents);
    my @entries = @{$changelog->entries};
    my $last = @entries ? $entries[0] : undef;
    my ($source, $version);
    my $changes;
    my @archs;
    my @dirs = ('..', '../build-area', '/var/cache/pbuilder/result');

    unshift(@dirs, $ENV{'DEBRELEASE_DEBS_DIR'})
      if exists($ENV{'DEBRELEASE_DEBS_DIR'});

    if (not $last) {
        my @errors = @{$changelog->errors};
        if (@errors) {
            print STDERR "Cannot parse debian/changelog due to errors:\n";
            for my $error (@errors) {
                print STDERR "$error->[2] (line $error->[1])\n";
            }
        } else {
            print STDERR "debian/changelog does not have any data?\n";
        }
        exit 2;
    }
    $version = $last->Version;
    $source = $last->Source;
    if (not defined $version or not defined $source) {
        $version//='<N/A>';
        $source//='<N/A>';
        print STDERR
          "Cannot determine source and version from debian/changelog:\n";
        print STDERR "Source: $source\n";
        print STDERR "Version: $source\n";
        exit 2;
    }
    # remove the epoch
    $version =~ s/^\d+://;
    if (exists $ENV{'DEB_BUILD_ARCH'}) {
        push @archs, $ENV{'DEB_BUILD_ARCH'};
    } else {
        my $arch = safe_qx('dpkg', '--print-architecture');
        chomp($arch);
        push @archs, $arch if $arch ne '';
    }
    push @archs, $ENV{'DEB_HOST_ARCH'} if exists $ENV{'DEB_HOST_ARCH'};
    # Maybe cross-built for something dpkg knows about...
    open(my $foreign, '-|', 'dpkg', '--print-foreign-architectures');
    while (my $line = <$foreign>) {
        chomp($line);
        # Skip already attempted architectures (e.g. via DEB_BUILD_ARCH)
        next if any { $_ eq $line } @archs;
        push(@archs, $line);
    }
    close($foreign);
    push @archs, qw(multi all source);
    foreach my $dir (@dirs) {
        foreach my $arch (@archs) {
            $changes = "$dir/${source}_${version}_${arch}.changes";
            return $changes if -f $changes;
        }
    }
    print STDERR "Cannot find changes file for ${source}/${version}, tried:\n";
    foreach my $arch (@archs) {
        print STDERR "  ${source}_${version}_${arch}.changes\n";
    }
    print STDERR " in the following dirs:\n";
    print STDERR '  ', join("\n  ", @dirs), "\n";
    exit 0;
}

sub parse_options {
    # init commandline parser
    Getopt::Long::config('default', 'bundling',
        'no_getopt_compat','no_auto_abbrev','permute');

    # process commandline options
    Getopt::Long::GetOptions(%opthash)
      or fatal_error("error parsing options\n");

    # root permissions?
    # check if effective UID is 0
    if ($> == 0 and not $opt{'allow-root'}) {
        print STDERR join(q{ },
            'warning: the authors of lintian do not',
            "recommend running it with root privileges!\n");
    }

    if ($opt{'ignore-lintian-env'}) {
        delete($ENV{$_}) for grep { m/^LINTIAN_/ } keys %ENV;
    }

    # option --all and packages specified at the same time?
    if ($opt{'packages-from-file'} and $#ARGV+1 > 0) {
        print STDERR join(q{ },
            'warning: option --packages-from-file',
            "cannot be mixed with package parameters!\n");
        print STDERR "(will ignore --packages-from-file option)\n";
        delete($opt{'packages-from-file'});
    }

    # check specified action
    $action = 'check' unless $action;

    fatal_error('Cannot use profile together with --ftp-master-rejects.')
      if $opt{'LINTIAN_PROFILE'} and $opt{'ftp-master-rejects'};
    # --ftp-master-rejects is implemented in a profile
    $opt{'LINTIAN_PROFILE'} = 'debian/ftp-master-auto-reject'
      if $opt{'ftp-master-rejects'};

    return;
}

sub _update_profile {
    my ($profile, $tags, $sup_check, $sup_tags, $only_check) = @_;
    my %abbrev = ();

    if ($sup_check || $only_check) {
        # Build an abbreviation map
        for my $c ($profile->scripts(1)) {
            my $cs = $profile->get_script($c, 1);
            next unless $cs->abbrev;
            $abbrev{$cs->abbrev} = $cs;
        }
    }

    # if tags are listed explicitly (--tags) then show them even if
    # they are pedantic/experimental etc.  However, for --check-part
    # people explicitly have to pass the relevant options.
    if ($checks || $check_tags) {
        $profile->disable_tags($profile->tags);
        if ($check_tags) {
            $tags->show_experimental(1);
            # discard whatever is in @display_level and request
            # everything
            @display_level = ();
            display_infotags();
            display_pedantictags();
            display_classificationtags();
            $profile->enable_tags(split /,/, $check_tags);
        } else {
            for my $c (split /,/, $checks) {
                if ($c eq 'all') {
                    my @all
                      = map {$profile->get_script($_, 1) }$profile->scripts(1);
                    $profile->enable_tags($_->tags)for @all;
                    next;
                }
                my $cs = $profile->get_script($c, 1) || $abbrev{$c};
                fatal_error("Unrecognized check script (via -C): $c")
                  unless $cs;
                $profile->enable_tags($cs->tags);
            }
        }
    } elsif ($sup_check) {
        # we are disabling checks
        for my $c (split(/,/, $sup_check)) {
            my $cs = $profile->get_script($c, 1) || $abbrev{$c};
            fatal_error("Unrecognized check script (via -X): $c") unless $cs;
            $profile->disable_tags($cs->tags);
        }
    }

    # --suppress-tags{,-from-file} can appear alone, but can also be
    # mixed with -C or -X.  Though, ignore it with --tags.
    if (%$sup_tags and not $check_tags) {
        $profile->disable_tags(keys %$sup_tags);
    }
    return;
}

# }}}

# {{{ Exit handler.

sub END {

    $SIG{'INT'} = 'DEFAULT';
    $SIG{'QUIT'} = 'DEFAULT';

    if (1) {
        # Prevent LAB->close, $unpacker->kill_jobs etc. from affecting
        # the exit code.
        local ($!, $?, $@);
        my %already_closed;

        for my $to_close (@CLOSE_AT_END) {

            my ($fd, $filename) = @{$to_close};
            my $fno = fileno($fd);

            # Already closed?  Can happen with e.g.
            #   --perf-output '&1' --status-log '&1'
            next
              if not defined($fno);

            next
              if $fno > -1 and $already_closed{$fno}++;

            eval {close($fd);};
            if (my $err = $@) {
                # Don't use L::Output here as it might be (partly) cleaned
                # up.
                print STDERR "warning: closing ${filename} failed: $err\n";
            }
        }
    }
}

sub _die_in_signal_handler {
    die("N: Interrupted.\n");
}

sub retrigger_signal {
    # Re-kill ourselves with the same signal to ensure that the exit
    # code reflects that we died by a signal.
    local $SIG{$received_signal} = \&_die_in_signal_handler;
    $OUTPUT->debug_msg(2, "Retriggering signal SIG${received_signal}");
    return kill($received_signal, $$);
}

sub interrupted {
    $received_signal = $_[0];
    $SIG{$received_signal} = 'DEFAULT';
    print {$STATUS_FD} "ack-signal SIG${received_signal}\n";
    return _die_in_signal_handler();
}

# }}}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
