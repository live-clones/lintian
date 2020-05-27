#!/usr/bin/perl -w
# {{{ Legal stuff
# Lintian -- Debian package checker
#
# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2017-2019 Chris Lamb <lamby@debian.org>
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

use v5.20;
use warnings;
use utf8;
use autodie;

use Cwd qw(abs_path);
use Carp qw(croak verbose);
use Config::Tiny;
use Getopt::Long();
use List::Compare;
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
use Lintian::Util qw(safe_qx);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COMMA => q{,};
use constant NEWLINE => qq{\n};

# only in GNOME; need original environment
my $interactive = -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT));
my $hyperlinks_capable = $interactive && qx{env | fgrep -i gnome};

sanitize_environment();

# }}}

# {{{ Application Variables

# Environment variables Lintian cares about - the list contains
# the ones that can also be set via the config file
#
# %option (defined below) will be updated with values of the env
# after parsing cmd-line options.  A given value in %option is
# updated to use the ENV variable if the one in %option is undef
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

# options set in config file
my %config;

# hash of some flags from cmd or cfg
my %option = (
    # init some cmd-line value defaults
    'debug'             => 0,
    'jobs'              => default_parallel(),
);

# must be an empty array reference
$option{'fail-on'} = [];

my $experimental_output_opts;

my @CLOSE_AT_END;
my $OUTPUT = Lintian::Output::Standard->new;
my (@display_level, %display_source, %suppress_tags);
my ($checks, $check_tags, $dont_check, $received_signal);
my $user_dirs = $ENV{'LINTIAN_ENABLE_USER_DIRS'} // 1;
my $exit_code = 0;
my $STATUS_FD;

# }}}

# {{{ Setup Code

sub lintian_banner {
    my $lintian_version = dplint::lintian_version();
    return "Lintian v${lintian_version}";
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
    --fail-on error,warning,info,pedantic,experimental,override
                              define condition for exit status 2 (default: none)
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

# Record Parts requested for checking
# Options: -C|--check-part
sub record_check_part {
    if ($checks) {
        die "multiple -C or --check-part options not allowed\n";
    }
    if ($dont_check) {
        die
"-C or --check-part and -X or --dont-check-part options may not appear together\n";
    }
    $checks = "$_[1]";
    return;
}

# Record Parts requested for checking
# Options: -T|--tags
sub record_check_tags {
    if ($check_tags) {
        die "multiple -T or --tags options not allowed\n";
    }
    if ($checks) {
        die
"both -T or --tags and -C or --check-part options may not appear together\n";
    }
    if ($dont_check) {
        die
"both -T or --tags and -X or --dont-check-part options may not appear together\n";
    }
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
    if ($dont_check) {
        die "multiple -X or --dont-check-part options not allowed\n";
    }
    if ($checks) {
        die
"both -C or --check-part and -X or --dont-check-part options may not appear together\n";
    }
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
    my $severity = $level;
    $op = '=' unless defined $op;
    $rel = '=' unless defined $rel;
    push(@display_level, [$op, $rel, $severity]);
    return;
}

# Process -I|--display-info flag
sub display_infotags {
    push(@display_level, ['+', '>=', 'info']);
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
    push(@display_level,['=', '>=', 'warning'],);
    return;
}

# Process --display-source flag
sub record_display_source {
    $display_source{$_[1]} = 1;
    return;
}

# Process -q|--quite flag
sub record_quiet {
    $option{'verbose'} = -1;
    return;
}

sub record_option_too_late {
    die
"Warning: --include-dir and --[no-]user-dirs should be the first option(s) if given\n";
}

# Process overrides option in the cfg files
sub cfg_fail_on {
    my ($name, $value) = @_;

    @{$option{'fail-on'}} = split(/,/, $value)
      unless scalar @{$option{'fail-on'}};

    return;
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
        die "$var and display-level may not both appear in the config file.\n"
          if $config{'display-level'};

        return unless $val; # case "display-info=no" (or "pedantic=no")

        # We are only supposed to modify @display_level if it was not
        # set by a command-line option.  However, both display-info
        # and pedantic comes here so we cannot determine this solely
        # by checking if @display_level is empty.  We use
        # "__conf-display-opts" to determine if @display_level was set
        # by a conf option or not.
        return if @display_level && !$config{'__conf-display-opts'};

        $config{'__conf-display-opts'} = 1;
        display_infotags() if $var eq 'display-info';
        display_pedantictags() if $var eq 'pedantic';
    } elsif ($var eq 'display-level'){
        foreach my $other (qw(pedantic display-info)) {
            die
"$other and display-level may not both appear in the config file.\n"
              if $config{$other};
        }

        return if @display_level;

        # trim both ends
        $val =~ s/^\s+|\s+$//g;

        foreach my $dl (split m/\s++/, $val) {
            record_display_level('display-level', $dl);
        }
    }
    return;
}

# Processes quiet and verbose options in cfg files.
# - dies if quiet and verbose are used together
# - sets the verbosity level ($option{'verbose'}) unless
#   already set.
sub cfg_verbosity {
    my ($var, $val) = @_;
    if (   ($var eq 'verbose' && exists $config{'quiet'})
        || ($var eq 'quiet' && exists $config{'verbose'})) {
        die "verbose and quiet may not both appear in the config file.\n";
    }
    # quiet = no or verbose = no => no change
    return unless $val;
    # Do not change the value if set by command line.
    return if defined $option{'verbose'};
    # quiet = yes => verbosity_level = -1
    #
    # technically this allows you to enable verbose by using "quiet =
    # -1" (etc.), but most people will probably not use this
    # "feature".
    $val = -$val if $var eq 'quiet';
    $option{'verbose'} = $val;
    return;
}

# Process overrides option in the cfg files
sub cfg_override {
    my ($var, $val) = @_;
    return if defined $option{'no-override'};
    # This option is inverted in the config file
    $option{'no-override'} = !$val;
    return;
}

# Hash used to process commandline options
my %getoptions = (
    # ------------------ actions
    'check|c' => \$option{check},
    'check-part|C=s' => \&record_check_part,
    'tags|T=s' => \&record_check_tags,
    'tags-from-file=s' => \&record_check_tags_from_file,
    'ftp-master-rejects|F' => \$option{'ftp-master-rejects'},
    'dont-check-part|X=s' => \&record_dont_check_part,

    # ------------------ general options
    'help|h:s' => \&syntax,
    'version|V' => \&banner,
    'print-version' => \&banner,

    'verbose|v' => \$option{'verbose'},
    'debug|d+' => \$option{'debug'}, # Count the -d flags
    'quiet|q' => \&record_quiet, # sets $option{'verbose'} to -1
    'perf-debug' => \$option{'perf-debug'},
    'perf-output=s' => \$option{'perf-output'},
    'status-log=s' => \$option{'status-log'},

    # ------------------ behaviour options
    'info|i' => \$option{'info'},
    'display-info|I' => \&display_infotags,
    'display-experimental|E!' => \$option{'display-experimental'},
    'pedantic' => \&display_pedantictags,
    'display-level|L=s' => \&record_display_level,
    'default-display-level' => \&default_display_level,
    'display-source=s' => \&record_display_source,
    'suppress-tags=s' => \&record_suppress_tags,
    'suppress-tags-from-file=s' => \&record_suppress_tags_from_file,
    'no-override|o' => \$option{'no-override'},
    'show-overrides' => \$option{'show-overrides'},
    'hide-overrides' => sub { $option{'show-overrides'} = 0; },
    'color=s' => \$option{'color'},
    'hyperlinks=s' => \$option{'hyperlinks'},
    'allow-root' => \$option{'allow-root'},
    'fail-on=s' => $option{'fail-on'},
    'keep-lab' => \$option{'keep-lab'},
    'no-tag-display-limit' => sub { $option{'tag-display-limit'} = 0; },
    'tag-display-limit=i' => \$option{'tag-display-limit'},

    # ------------------ configuration options
    'cfg=s' => \$option{'LINTIAN_CFG'},
    'no-cfg' => \$option{'no-cfg'},
    'profile=s' => \$option{'LINTIAN_PROFILE'},

    'jobs|j=i' => \$option{'jobs'},
    'ignore-lintian-env' => \$option{'ignore-lintian-env'},
    'include-dir=s' => \&record_option_too_late,
    'user-dirs!' => \&record_option_too_late,

    # ------------------ package selection options
    'packages-from-file=s' => \$option{'packages-from-file'},

    # ------------------ experimental
    'exp-output:s' => \$experimental_output_opts,
);

sub main {

    $0 = join(' ', $0, @ARGV);

    #turn off file buffering
    STDOUT->autoflush;
    STDERR->autoflush;

    # layers are additive; STDOUT already had UTF-8 from frontend/dplint
    binmode(STDERR, ':encoding(UTF-8)');

    # Globally ignore SIGPIPE.  We'd rather deal with error returns from write
    # than randomly delivered signals.
    $SIG{PIPE} = 'IGNORE';

    parse_options();

    # environment variables override settings in conf file, so load them now
    # assuming they were not set by cmd-line options
    foreach my $var (@ENV_VARS) {
  # note $option{$var} will usually always exists due to the call to GetOptions
  # so we have to use "defined" here
        $option{$var} = $ENV{$var} if $ENV{$var} && !defined $option{$var};
    }

    # Check if we should load a config file
    if ($option{'no-cfg'}) {
        $option{'LINTIAN_CFG'} = '';
    } else {
        if (not $option{'LINTIAN_CFG'}) {
            $option{'LINTIAN_CFG'} = _find_cfg_file();
        }
        # _find_cfg_file() can return undef
        if ($option{'LINTIAN_CFG'}) {
            parse_config_file($option{'LINTIAN_CFG'});
        }
        $option{'LINTIAN_CFG'} //= '';
    }

    $ENV{'TMPDIR'} = $option{'TMPDIR'} if defined($option{'TMPDIR'});

    if (defined $experimental_output_opts) {
        my %output = map { split(/=/) } split(/,/, $experimental_output_opts);
        foreach (keys %output) {
            if ($_ eq 'format') {
                if ($output{$_} eq 'colons') {
                    require Lintian::Output::ColonSeparated;
                    $OUTPUT= Lintian::Output::ColonSeparated->new;
                } elsif ($output{$_} eq 'letterqualifier') {
                    require Lintian::Output::LetterQualifier;
                    $OUTPUT= Lintian::Output::LetterQualifier->new;
                } elsif ($output{$_} eq 'xml') {
                    require Lintian::Output::XML;
                    $OUTPUT = Lintian::Output::XML->new;
                } elsif ($output{$_} eq 'json') {
                    require Lintian::Output::JSON;
                    $OUTPUT = Lintian::Output::JSON->new;
                } elsif ($output{$_} eq 'fullewi') {
                    require Lintian::Output::FullEWI;
                    $OUTPUT = Lintian::Output::FullEWI->new;
                } elsif ($output{$_} eq 'universal') {
                    require Lintian::Output::Universal;
                    $OUTPUT = Lintian::Output::Universal->new;
                }
            }
        }
    }

    # check permitted values for --color / color
    #  - We set the default to 'auto' here; because we cannot do
    #    it before the config check.
    $option{'color'} = 'auto' unless defined($option{'color'});
    if (    $option{'color'}
        and $option{'color'} !~ /^(?:never|always|auto|html)$/) {
        die "The color value must be one of never, always, auto or html.\n";
    }

    if ($option{'color'} eq 'never') {
        $option{'hyperlinks'} //= 'off';
    } else {
        $option{'hyperlinks'} //= 'on';
    }
    die "The hyperlink value must be on or off\n"
      unless $option{'hyperlinks'} =~ /^(?:on|off)$/;

    if ($option{'verbose'} || !-t STDOUT) {
        $option{'tag-display-limit'} //= 0;
    } else {
        $option{'tag-display-limit'} //= 4;
    }

    if ($option{'debug'}) {
        $option{'verbose'} = 1;
        $ENV{'LINTIAN_DEBUG'} = $option{'debug'};
        $SIG{__DIE__} = sub { Carp::confess(@_) };
    } else {
        # Ensure verbose has a defined value
        $option{'verbose'} //= 0;
    }

    $OUTPUT->verbosity_level($option{'verbose'});
    $OUTPUT->debug($option{'debug'});

    $OUTPUT->color($option{'color'});
    $OUTPUT->tty_hyperlinks($hyperlinks_capable&& $option{hyperlinks} eq 'on');
    $OUTPUT->tag_display_limit($option{'tag-display-limit'});
    $OUTPUT->showdescription($option{'info'});

    $OUTPUT->perf_debug($option{'perf-debug'});
    if (defined(my $perf_log = $option{'perf-output'})) {
        my $fd = open_file_or_fd($perf_log, '>');
        $OUTPUT->perf_log_fd($fd);

        push(@CLOSE_AT_END, [$fd, $perf_log]);
    }

    if (defined(my $status_log = $option{'status-log'})) {
        $STATUS_FD = open_file_or_fd($status_log, '>');
        $STATUS_FD->autoflush;

        push(@CLOSE_AT_END, [$STATUS_FD, $status_log]);
    } else {
        open($STATUS_FD, '>', '/dev/null');
    }

    # check for arguments
    if ($#ARGV == -1
        and not $option{'packages-from-file'}) {
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

    if ($option{'debug'}) {
        my $banner = lintian_banner();
        # Print Debug banner, now that we're finished determining
        # the values and have Lintian::Output available
        $OUTPUT->debug_msg(
            1,$banner,
            "Lintian root directory: $INIT_ROOT",
            "Configuration file: $option{'LINTIAN_CFG'}",
            'UTF-8: ✓ (☃)',
            $OUTPUT->delimiter,
        );
    }

    # dies on error
    my $PROFILE = dplint::load_profile($option{'LINTIAN_PROFILE'});

    # Ensure $option{'LINTIAN_PROFILE'} is defined
    $option{'LINTIAN_PROFILE'} = $PROFILE->name
      unless defined($option{'LINTIAN_PROFILE'});
    $OUTPUT->v_msg('Using profile ' . $PROFILE->name . '.');
    Lintian::Data->set_vendor($PROFILE);

    $option{'display-source'} = [keys %display_source];

    if ($dont_check || %suppress_tags || $checks || $check_tags) {
        _update_profile($PROFILE, $dont_check, \%suppress_tags,$checks);
    }

    # initialize display level settings; dies on error
    $PROFILE->display(@{$_})for @display_level;

    $SIG{'TERM'} = \&interrupted;
    $SIG{'INT'} = \&interrupted;
    $SIG{'QUIT'} = \&interrupted;

    my @subjects;
    push(@subjects, @ARGV);

    if ($option{'packages-from-file'}){
        my $fd = open_file_or_fd($option{'packages-from-file'}, '<');

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
        die "$path is not a file\n" unless -f $path;

        # in ubuntu, automatic dbgsym packages end with .ddeb
        die
"bad package file name $path (neither .deb, .udeb, .ddeb, .changes, .dsc or .buildinfo file)\n"
          unless $path =~ m/\.(?:[u|d]?deb|dsc|changes|buildinfo)$/;

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
            $exit_code = 1;
        }
    }

    if ($pool->empty) {
        $OUTPUT->v_msg('No packages selected.');
        exit $exit_code;
    }

    $ENV{INIT_ROOT} = $INIT_ROOT;

    $pool->process($PROFILE, \$exit_code, \%option, $STATUS_FD, $OUTPUT);

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

    # for keys appearing multiple times, now uses the last value
    my $object = Config::Tiny->read($config_file, 'utf8');
    my $error = $object->errstr;
    die "syntax error in configuration file $config_file: " . $error . NEWLINE
      if length $error;

    # used elsewhere to check for values already set
    %config = %{$object->{_} // {}};

    # Options that can appear in the config file
    my %destination = (
        'color'                => \$option{'color'},
        'hyperlinks'           => \$option{'hyperlinks'},
        'display-experimental' => \$option{'display-experimental'},
        'display-info'         => \&cfg_display_level,
        'display-level'        => \&cfg_display_level,
        'fail-on'              => \&cfg_fail_on,
        'info'                 => \$option{'info'},
        'jobs'                 => \$option{'jobs'},
        'pedantic'             => \&cfg_display_level,
        'quiet'                => \&cfg_verbosity,
        'override'             => \&cfg_override,
        'show-overrides'       => \$option{'show-overrides'},
        'suppress-tags'        => \&record_suppress_tags,
        'suppress-tags-from-file' => \&record_suppress_tags_from_file,
        'tag-display-limit'    => \$option{'tag-display-limit'},
        'verbose'              => \&cfg_verbosity,
    );

    # check keys against known settings
    my $knownlc = List::Compare->new([keys %config], [keys %destination]);
    my @unknown = $knownlc->get_Lonly;
    die "Unknown setting in $config_file: " . join(SPACE, @unknown) . NEWLINE
      if @unknown;

    # some environment variables can be set from the config file
    my $envlc = List::Compare->new([keys %config], \@ENV_VARS);
    my @from_file = $envlc->get_intersection;

    my @already = grep { defined $ENV{$_} } @from_file;
    warn "Already have setting from $config_file in the environment: "
      . join(SPACE, @already)
      . NEWLINE
      if @already;

    my @not_yet = grep { !defined $ENV{$_} } @from_file;
    $ENV{$_} = $config{$_} for @not_yet;

    # substitute some special variables
    s{\$HOME/}{$ENV{'HOME'}/}g for values %config;
    s{\~/}{$ENV{'HOME'}/}g for values %config;

    # Translate boolean strings to "0" or "1"; ignore
    # errors as not all values are (intended to be)
    # booleans.
    my $booleanlc
      = List::Compare->new([keys %config], [qw(jobs tag-display-limit)]);
    eval { $config{$_} = parse_boolean($config{$_}); }
      for $booleanlc->get_Lonly;

    # initialize variables
    my @names = grep { defined $config{$_} } keys %destination;

    my @scalars = grep { ref $destination{$_} eq 'SCALAR' } @names;
    my @undefined = grep { defined ${$destination{$_}} } @scalars;
    ${$destination{$_}} = $config{$_} for @undefined;

    my @coderefs = grep { ref $destination{$_} eq 'CODE' } @names;
    $destination{$_}->($_, $config{$_}) for @coderefs;

    return;
}

=item parse_boolean (STR)

Attempt to parse STR as a boolean and return its value.
If STR is not a valid/recognised boolean, the sub will
invoke croak.

The following values recognised (string checks are not
case sensitive):

=over 4

=item The integer 0 is considered false

=item Any non-zero integer is considered true

=item "true", "y" and "yes" are considered true

=item "false", "n" and "no" are considered false

=back

=cut

sub parse_boolean {
    my ($str) = @_;
    return $str == 0 ? 0 : 1 if $str =~ m/^-?\d++$/o;
    $str = lc $str;
    return 1 if $str eq 'true' or $str =~ m/^y(?:es)?$/;
    return 0 if $str eq 'false' or $str =~ m/^no?$/;
    croak "\"$str\" is not a valid boolean value";
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
        exit 1;
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
        exit 1;
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
    Getopt::Long::GetOptions(%getoptions)
      or die "error parsing options\n";

    # root permissions?
    # check if effective UID is 0
    if ($> == 0 and not $option{'allow-root'}) {
        print STDERR join(q{ },
            'warning: the authors of lintian do not',
            "recommend running it with root privileges!\n");
    }

    if ($option{'ignore-lintian-env'}) {
        delete($ENV{$_}) for grep { m/^LINTIAN_/ } keys %ENV;
    }

    # option --all and packages specified at the same time?
    if ($option{'packages-from-file'} and $#ARGV+1 > 0) {
        print STDERR join(q{ },
            'warning: option --packages-from-file',
            "cannot be mixed with package parameters!\n");
        print STDERR "(will ignore --packages-from-file option)\n";
        delete($option{'packages-from-file'});
    }

    die "Cannot use profile together with --ftp-master-rejects.\n"
      if $option{'LINTIAN_PROFILE'} and $option{'ftp-master-rejects'};
    # --ftp-master-rejects is implemented in a profile
    $option{'LINTIAN_PROFILE'} = 'debian/ftp-master-auto-reject'
      if $option{'ftp-master-rejects'};

    # check arguments to --fail-on
    @{$option{'fail-on'}} = split(/,/, join(COMMA, @{$option{'fail-on'}}));
    my @unknown_fail_on
      = grep {!/^(?:error|warning|info|pedantic|experimental|override)$/ }
      @{$option{'fail-on'}};
    die "Unrecognized fail-on argument: $_\n" for @unknown_fail_on;

    return;
}

sub _update_profile {
    my ($profile, $sup_check, $sup_tags, $only_check) = @_;

    # if tags are listed explicitly (--tags) then show them even if
    # they are pedantic/experimental etc.  However, for --check-part
    # people explicitly have to pass the relevant options.
    if ($checks || $check_tags) {
        $profile->disable_tag($_) for $profile->enabled_tags;
        if ($check_tags) {
            $option{'display-experimental'} = 1;
            # discard whatever is in @display_level and request
            # everything
            @display_level = ();
            display_infotags();
            display_pedantictags();
            display_classificationtags();
            $profile->enable_tag($_) for split(/,/, $check_tags);
        } else {
            for my $c (split /,/, $checks) {
                if ($c eq 'all') {
                    my @all
                      = map {$profile->get_checkinfo($_)}
                      $profile->known_checks;
                    my @tags = map { $_->tags } @all;
                    $profile->enable_tag($_) for @tags;
                    next;
                }
                my $cs = $profile->get_checkinfo($c);
                die "Unrecognized check script (via -C): $c\n"
                  unless $cs;
                $profile->enable_tag($_) for $cs->tags;
            }
        }
    } elsif ($sup_check) {
        # we are disabling checks
        for my $c (split(/,/, $sup_check)) {
            my $cs = $profile->get_checkinfo($c);
            die "Unrecognized check script (via -X): $c\n" unless $cs;
            $profile->disable_tag($_) for $cs->tags;
        }
    }

    # --suppress-tags{,-from-file} can appear alone, but can also be
    # mixed with -C or -X.  Though, ignore it with --tags.
    if (%$sup_tags and not $check_tags) {
        $profile->disable_tag($_) for keys %$sup_tags;
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
    die "N: Interrupted.\n";
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
