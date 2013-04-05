# init.d -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz
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

package Lintian::init_d;
use strict;
use warnings;
use autodie qw(opendir closedir);

use File::Basename qw(dirname);
use List::MoreUtils qw(any none);

use Lintian::Data;
use Lintian::Tags qw(tag);
use Lintian::Util qw(fail);

# A list of valid LSB keywords.  The value is 0 if optional and 1 if required.
my %lsb_keywords = (provides            => 1,
                    'required-start'    => 1,
                    'required-stop'     => 1,
                    'should-start'      => 0,
                    'should-stop'       => 0,
                    'default-start'     => 1,
                    'default-stop'      => 1,
                    # These two are actually optional, but we mark
                    # them as required and give them a weaker tag if
                    # they are missing.
                    'short-description' => 1,
                    'description'       => 1);

# These init script names should probably not be used in dependencies.
# Instead, the corresponding virtual facility should be used.
#
# checkroot is not included here since cryptsetup needs the root file system
# mounted but not any other local file systems and therefore correctly depends
# on checkroot.  There may be other similar situations.
my %implied_dependencies =
    (
     'mountall'   => '$local_fs',
     'mountnfs'   => '$remote_fs',
     'hwclock'    => '$time',
     'portmap'    => '$portmap',
     'named'      => '$named',
     'bind9'      => '$named',
     'networking' => '$network',
     'syslog'     => '$syslog',
     'rsyslog'    => '$syslog',
     'sysklogd'   => '$syslog'
    );

our $VIRTUAL_FACILITIES = Lintian::Data->new('init.d/virtual_facilities');
# Regex to match names of init.d scripts; it is a bit more lax than
# package names (e.g. allows "_").  We do not allow it to start with a
# "dash" to avoid confusing it with a command-line option (also,
# update-rc.d does not allow this).
our $INITD_NAME_REGEX = qr/[\w\.\+][\w\-\.\+]*/;

sub run {

my (undef, undef, $info) = @_;

my $initd_dir = $info->lab_data_path ('init.d');

my $postinst = $info->control('postinst');
my $preinst = $info->control('preinst');
my $postrm = $info->control('postrm');
my $prerm = $info->control('prerm');

my %initd_postinst;
my %initd_postrm;

my $opts_r = qr/-\S+\s*/;
my $action_r = qr/\w+/;
my $exclude_r = qr/if\s+\[\s+-x\s+\S*update-rc\.d/;

# read postinst control file
if ( -f $postinst and not -l $postinst) {
    open(IN, '<', $postinst)
        or fail "open postinst: $!";
    while (<IN>) {
        next if /$exclude_r/o;
        s/\#.*$//o;
        next unless /^(?:.+;|^\s*system[\s\(\']+)?\s*update-rc\.d\s+
            (?:$opts_r)*($INITD_NAME_REGEX)\s+($action_r)/xo;
        my ($name,$opt) = ($1,$2);
        next if $opt eq 'remove';
        if ($initd_postinst{$name}++ == 1) {
            tag 'duplicate-updaterc.d-calls-in-postinst', $name;
            next;
        }
        unless (m,>\s*/dev/null,o) {
            tag 'output-of-updaterc.d-not-redirected-to-dev-null', "$name postinst";
        }
    }
    close(IN);
}

# read preinst control file
if ( -f $preinst and not -l $preinst) {
    open(IN, '<', $preinst)
        or fail "open preinst: $!";
    while (<IN>) {
        next if /$exclude_r/o;
        s/\#.*$//o;
        next unless m/update-rc\.d \s+
                       (?:$opts_r)*($INITD_NAME_REGEX) \s+
                       ($action_r)/ox;
        my ($name,$opt) = ($1,$2);
        next if $opt eq 'remove';
        tag 'preinst-calls-updaterc.d', $name;
    }
    close(IN);
}

# read postrm control file
if ( -f $postrm and not -l $postrm) {
    open(IN, '<', $postrm)
        or fail "open postrm: $!";
    while (<IN>) {
        next if /$exclude_r/o;
        s/\#.*$//o;
        next unless m/update-rc\.d\s+($opts_r)*($INITD_NAME_REGEX)/o;
        if ($initd_postrm{$2}++ == 1) {
            tag 'duplicate-updaterc.d-calls-in-postrm', $2;
            next;
        }
        unless (m,>\s*/dev/null,o) {
            tag 'output-of-updaterc.d-not-redirected-to-dev-null', "$2 postrm";
        }
    }
    close(IN);
}

# read prerm control file
if ( -f $prerm and not -l $prerm) {
    open(IN, '<', $prerm)
        or fail "open prerm: $!";
    while (<IN>) {
        next if /$exclude_r/o;
        s/\#.*$//o;
        next unless m/update-rc\.d\s+($opts_r)*($INITD_NAME_REGEX)/o;
        tag 'prerm-calls-updaterc.d', $2;
    }
    close(IN);
}

# init.d scripts have to be removed in postrm
for (keys %initd_postinst) {
    if ($initd_postrm{$_}) {
        delete $initd_postrm{$_};
    } else {
        tag 'postrm-does-not-call-updaterc.d-for-init.d-script', "etc/init.d/$_";
    }
}
for (keys %initd_postrm) {
    tag 'postrm-contains-additional-updaterc.d-calls', "etc/init.d/$_";
}

foreach my $initd_file (keys %initd_postinst) {
    next unless $initd_file;
    my $initd_path = "$initd_dir/$initd_file";

    # init.d scripts have to be marked as conffiles unless they're symlinks.
    unless ($info->is_conffile ("etc/init.d/$initd_file")
            or -l $initd_path) {
        tag 'init.d-script-not-marked-as-conffile', "etc/init.d/$initd_file";
    }

    # Check if file exists in package and check the script for other issues if
    # it was included in the package.
    if (-f $initd_path) {
        check_init ($initd_file, $initd_path);
    } elsif (not -l $initd_path) {
        tag 'init.d-script-not-included-in-package', "etc/init.d/$initd_file";
    }
}

# files actually installed in /etc/init.d should match our list :-)
opendir(my $dirfd, $initd_dir);
for my $script (readdir($dirfd)) {
    my $tagname = 'script-in-etc-init.d-not-registered-via-update-rc.d';
    next if any {$script eq $_} qw(. .. README skeleton rc rcS);

    my $script_path = "$initd_dir/$script";

    # In an upstart system, such as Ubuntu, init scripts are symlinks to
    # upstart-job which are not registered with update-rc.d.
    if (-l $script_path) {
        my $target = readlink ($script_path);
        if ($target =~ m,(?:\A|/)lib/init/upstart-job\z,) {
            $tagname = 'upstart-job-in-etc-init.d-not-registered-via-update-rc.d';
        }
    }


    # If $initd_postinst is true for this script, we already checked the
    # syntax in the above loop.  Check the syntax of unregistered scripts so
    # that we get more complete Lintian coverage in the first pass.
    unless ($initd_postinst{$script}) {
        tag $tagname, "etc/init.d/$script";
        check_init ($script, $script_path) if -f $script_path;
    }
}
closedir($dirfd);

}

sub check_init {
    my ($initd_file, $initd_path) = @_;

    # In an upstart system, such as Ubuntu, init scripts are symlinks to
    # upstart-job.  It doesn't make sense to check the syntax of upstart-job,
    # so skip the checks of the init script itself in that case.
    if (-l $initd_path) {
        my $target = readlink ($initd_path);
        if ($target =~ m,(?:\A|/)lib/init/upstart-job\z,) {
            return;
        }
        if (!is_ancestor_of(dirname($initd_path), $initd_path)) {
            # unsafe symlink, skip.  NB: dirname($initd_path) is safe
            # because coll/init.d does sanity checking for us.
            return;
        }
    }
    open IN, '<', $initd_path
        or fail("cannot open init.d file $initd_file: $!");
    my (%tag, %lsb);
    my $in_file_test = 0;
    my %needs_fs = ('remote' => 0, 'local' => 0);
    while (defined(my $l = <IN>)) {
        if ($. == 1 && $l =~ m,^\#!\s*(/usr/[^\s]+),) {
            tag 'init.d-script-uses-usr-interpreter', "etc/init.d/$initd_file $1";
        }
        if ($l =~ m/^\#\#\# BEGIN INIT INFO/) {
            if ($lsb{BEGIN}) {
                tag 'init.d-script-has-duplicate-lsb-section', "etc/init.d/$initd_file";
                next;
            }
            $lsb{BEGIN} = 1;
            my $last;

            # We have an LSB keyword section.  Parse it and save the data
            # in %lsb for analysis.
            while (defined(my $l = <IN>)) {
                if ($l =~ /^\#\#\# END INIT INFO/) {
                    $lsb{END} = 1;
                    last;
                } elsif ($l !~ /^\#/) {
                    tag 'init.d-script-has-unterminated-lsb-section', "etc/init.d/${initd_file}:$.";
                    last;
                } elsif ($l =~ /^\# ([a-zA-Z-]+):\s*(.*?)\s*$/) {
                    my $keyword = lc $1;
                    my $value = $2;
                    tag 'init.d-script-has-duplicate-lsb-keyword', "etc/init.d/${initd_file}:$. $keyword"
                        if (defined $lsb{$keyword});
                    tag 'init.d-script-has-unknown-lsb-keyword', "etc/init.d/${initd_file}:$. $keyword"
                        unless (defined ($lsb_keywords{$keyword}) || $keyword =~ /^x-/);
                    $lsb{$keyword} = defined($value) ? $value : '';
                    $last = $keyword;
                } elsif ($l =~ /^\#(\t|  )/ && $last eq 'description') {
                    my $value = $l;
                    $value =~ s/^\#\s*//;
                    $lsb{description} .= ' ' . $value;
                } else {
                    tag 'init.d-script-has-bad-lsb-line', "etc/init.d/${initd_file}:$.";
                }
            }
        }

        # Pretty dummy way to handle conditionals, but should be enough
        # for simple init scripts
        $in_file_test = 1 if ($l =~ m/\bif\s+.*?(?:test|\[)(?:\s+\!)?\s+-[efr]\s+/);
        $in_file_test = 0 if ($l =~ m/\bfi\b/);
        if (!$in_file_test && $l =~ m,^\s*\.\s+["'"]?(/etc/default/[\$\w/-]+),) {
            tag 'init.d-script-sourcing-without-test', "etc/init.d/${initd_file}:$. $1";
        }

        # This should be more sophisticated: ignore heredocs, ignore quoted
        # text and the arguments to echo, etc.
        $needs_fs{'remote'} = 1 if ($l =~ m,^[^\#]*/usr/,);
        $needs_fs{'local'}  = 1 if ($l =~ m,^[^\#]*/var/,);

        while ($l =~ s/^[^\#]*?(start|stop|restart|force-reload|status)//o) {
            $tag{$1} = 1;
        }
    }
    close(IN);

    # Make sure all of the required keywords are present.
    if (not $lsb{BEGIN}) {
        tag 'init.d-script-missing-lsb-section', "etc/init.d/${initd_file}";
    } else {
        for my $keyword (keys %lsb_keywords) {
            if ($lsb_keywords{$keyword} && !defined $lsb{$keyword}) {
                if ($keyword eq 'short-description') {
                    tag 'init.d-script-missing-lsb-short-description', "etc/init.d/${initd_file}";
                } elsif ($keyword eq 'description') {
                    tag 'init.d-script-missing-lsb-description', "etc/init.d/${initd_file}";
                } else {
                    tag 'init.d-script-missing-lsb-keyword', "etc/init.d/${initd_file} $keyword";
                }
            }
        }
    }

    # Check the runlevels.
    my %start;
    if (defined $lsb{'default-start'}) {
        for my $runlevel (split (/\s+/, $lsb{'default-start'})) {
            if ($runlevel =~ /^[sS0-6]$/) {
                $start{lc $runlevel} = 1;
                if ($runlevel eq '0' or $runlevel eq '6') {
                    tag 'init.d-script-starts-in-stop-runlevel',
                        "etc/init.d/${initd_file}", $runlevel;
                }
            } else {
                tag 'init.d-script-has-bad-start-runlevel', "etc/init.d/${initd_file}",
                    $runlevel;
            }
        }

        # No script should start at one of the 2-5 runlevels but not at
        # all of them
        my $start = join(' ', sort grep {$_ =~ /^[2-5]$/} keys %start);
        if (length($start) > 0 and $start ne '2 3 4 5') {
            my $base = $initd_file;
            $base =~ s,.*/,,;
            my @missing = grep { !defined $start{$_} } qw(2 3 4 5);
            tag 'init.d-script-missing-start', "etc/init.d/${initd_file}",
                @missing;
        }
    }
    if (defined $lsb{'default-stop'}) {
        my %stop;
        for my $runlevel (split (/\s+/, $lsb{'default-stop'})) {
            if ($runlevel =~ /^[sS0-6]$/) {
                $stop{$runlevel} = 1 unless $runlevel =~ /[sS2-5]/;
                if ($start{$runlevel}) {
                    tag 'init.d-script-has-conflicting-start-stop', "etc/init.d/${initd_file} $runlevel";
                }
                if ($runlevel =~ /[sS]/) {
                    tag 'init-d-script-stops-in-s-runlevel', "etc/init.d/${initd_file}";
                }
            } else {
                tag 'init.d-script-has-bad-stop-runlevel', "etc/init.d/${initd_file} $runlevel";
            }
        }

        # Scripts that stop in any of 0, 1, or 6 probably should stop in all
        # of them, with some special exceptions.
        my $stop = join(' ', sort keys %stop);
        if (length($stop) > 0 and $stop ne '0 1 6') {
            my $base = $initd_file;
            $base =~ s,.*/,,;
            if (none { $base eq $_ } qw(killprocs sendsigs halt reboot)) {
                my @missing = grep { !defined $stop{$_} } qw(0 1 6);
                tag 'init.d-script-possible-missing-stop', "etc/init.d/${initd_file}",
                    @missing;
            }
        }
    }
    if ($lsb{'provides'}) {
        my $provides_self;
        for my $facility (split(/\s+/, $lsb{'provides'})) {
            if ($facility =~ /^\$/) {
                tag 'init.d-script-provides-virtual-facility',
                    "etc/init.d/${initd_file}", $facility;
            }
            if ($initd_file =~/^\Q$facility\E(?:.sh)?$/) {
                $provides_self = 1;
            }
        }
        tag 'init.d-script-does-not-provide-itself', "etc/init.d/${initd_file}"
            unless $provides_self;
    }

    # If $remote_fs is needed $local_fs is not, since it's implied.
    $needs_fs{'local'} = 0 if $needs_fs{'remote'};

    # Separately check Required-Start and Required-Stop, since while they're
    # similar, they're not quite identical.  This could use some further
    # restructuring by pulling the regexes out as data tied to start/stop and
    # remote/local and then combining the loops.
    if (defined $lsb{'default-start'} && length($lsb{'default-start'})) {
        my @required = split(' ', $lsb{'required-start'} || '');
        if ($needs_fs{remote}) {
            if (none { /^\$(?:remote_fs|all)\z/ } @required) {
                tag 'init.d-script-missing-dependency-on-remote_fs',
                    "etc/init.d/${initd_file}: required-start";
            }
        }
        if ($needs_fs{local}) {
            if (none { /^\$(?:local_fs|remote_fs|all)\z/ } @required) {
                tag 'init.d-script-missing-dependency-on-local_fs',
                    "etc/init.d/${initd_file}: required-start";
            }
        }
    }
    if (defined $lsb{'default-stop'} && length($lsb{'default-stop'})) {
        my @required = split(' ', $lsb{'required-stop'} || '');
        if ($needs_fs{remote}) {
            if (none { /^(?:\$remote_fs|\$all|umountnfs)\z/ } @required) {
                tag 'init.d-script-missing-dependency-on-remote_fs',
                    "etc/init.d/${initd_file}: required-stop";
            }
        }
        if ($needs_fs{local}) {
            if (none { /^(?:\$(?:local|remote)_fs|\$all|umountn?fs)\z/ } @required) {
                tag 'init.d-script-missing-dependency-on-local_fs',
                    "etc/init.d/${initd_file}: required-stop";
            }
        }
    }

    # Check syntax rules that apply to all of the keywords.
    for my $keyword (qw(required-start should-start required-stop should-stop)) {
        next unless defined $lsb{$keyword};
        for my $dependency (split(/\s+/, $lsb{$keyword})) {
            if (defined $implied_dependencies{$dependency}) {
                tag 'init.d-script-should-depend-on-virtual-facility',
                    "etc/init.d/${initd_file}",
                    "$dependency -> $implied_dependencies{$dependency}";
            } elsif ($keyword =~ m/^required-/ && $dependency =~ m/^\$/) {
                tag 'init.d-script-depends-on-unknown-virtual-facility',
                    "etc/init.d/${initd_file}", $dependency
                    unless ($VIRTUAL_FACILITIES->known($dependency));
            }
        }
    }

    # all tags included in file?
    for my $option (qw(start stop restart force-reload)) {
        $tag{$option}
            or tag 'init.d-script-does-not-implement-required-option', "etc/init.d/${initd_file} $option";
    }

    for my $option (qw(status)) {
        $tag{$option}
            or tag 'init.d-script-does-not-implement-optional-option', "etc/init.d/${initd_file} $option";
    }
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
