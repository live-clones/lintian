# init.d -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2016-2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::InitD;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename qw(dirname);
use List::SomeUtils qw(any none);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };

# A list of valid LSB keywords.  The value is 0 if optional and 1 if required.
my %lsb_keywords = (
    provides            => 1,
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
    'description'       => 1
);

# These init script names should probably not be used in dependencies.
# Instead, the corresponding virtual facility should be used.
#
# checkroot is not included here since cryptsetup needs the root file system
# mounted but not any other local file systems and therefore correctly depends
# on checkroot.  There may be other similar situations.
my %implied_dependencies = (
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

# Regex to match names of init.d scripts; it is a bit more lax than
# package names (e.g. allows "_").  We do not allow it to start with a
# "dash" to avoid confusing it with a command-line option (also,
# update-rc.d does not allow this).
our $INITD_NAME_REGEX = qr/[\w\.\+][\w\-\.\+]*/;

my $OPTS_R = qr/-\S+\s*/;
my $ACTION_R = qr/\w+/;
my $EXCLUDE_R = qr/if\s+\[\s+-x\s+\S*update-rc\.d/;

my $ALWAYS_START
  = qr/^\s*#*\s*(?:[A-Z]_)?(?:ENABLED|DISABLED|[A-Z]*RUN|(?:NO_)?START)=/;

sub installable {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $processable = $self->processable;

    my $initd_dir = $processable->installed->resolve_path('etc/init.d/');
    my $postinst = $processable->control->lookup('postinst');
    my $preinst = $processable->control->lookup('preinst');
    my $postrm = $processable->control->lookup('postrm');
    my $prerm = $processable->control->lookup('prerm');

    my (%initd_postinst, %initd_postrm);

    # These will never be regular initscripts. (see #918459, #933383
    # and #941140 etc.)
    return if $pkg eq 'initscripts' or $pkg eq 'sysvinit';

    # read postinst control file
    if ($postinst and $postinst->is_file and $postinst->is_open_ok) {

        open(my $fd, '<', $postinst->unpacked_path)
          or die encode_utf8('Cannot open ' . $postinst->unpacked_path);

        while (my $line = <$fd>) {

            next
              if $line =~ /$EXCLUDE_R/;

            $line =~ s/\#.*$//;

            next
              unless $line =~ m{^(?:.+;|^\s*system[\s\(\']+)?\s*update-rc\.d\s+
            (?:$OPTS_R)*($INITD_NAME_REGEX)\s+($ACTION_R)}x;

            my ($name,$opt) = ($1,$2);
            next
              if $opt eq 'remove';

            if ($initd_postinst{$name}++ == 1) {
                $self->hint('duplicate-updaterc.d-calls-in-postinst', $name);
                next;
            }

            $self->hint('output-of-updaterc.d-not-redirected-to-dev-null',
                "$name postinst")
              unless $line =~ m{>\s*/dev/null};
        }
        close($fd);
    }

    # read preinst control file
    if ($preinst and $preinst->is_file and $preinst->is_open_ok) {

        open(my $fd, '<', $preinst->unpacked_path)
          or die encode_utf8('Cannot open ' . $preinst->unpacked_path);

        while (my $line = <$fd>) {

            next
              if $line =~ /$EXCLUDE_R/;

            $line =~ s/\#.*$//;
            next
              unless $line =~ m{update-rc\.d \s+
                       (?:$OPTS_R)*($INITD_NAME_REGEX) \s+
                       ($ACTION_R)}x;

            my ($name,$opt) = ($1,$2);
            next
              if $opt eq 'remove';

            $self->hint('preinst-calls-updaterc.d', $name);
        }
        close($fd);
    }

    # read postrm control file
    if ($postrm and $postrm->is_file and $postrm->is_open_ok) {

        open(my $fd, '<', $postrm->unpacked_path)
          or die encode_utf8('Cannot open ' . $postrm->unpacked_path);

        while (my $line = <$fd>) {

            next
              if $line =~ /$EXCLUDE_R/;

            $line =~ s/\#.*$//;

            next
              unless $line =~ /update-rc\.d\s+($OPTS_R)*($INITD_NAME_REGEX)/;

            my $name = $2;

            if ($initd_postrm{$name}++ == 1) {
                $self->hint('duplicate-updaterc.d-calls-in-postrm', $2);
                next;
            }

            $self->hint('output-of-updaterc.d-not-redirected-to-dev-null',
                "$name postrm")
              unless $line =~ m{>\s*/dev/null};
        }
        close($fd);
    }

    # read prerm control file
    if ($prerm and $prerm->is_file and $prerm->is_open_ok) {

        open(my $fd, '<', $prerm->unpacked_path)
          or die encode_utf8('Cannot open ' . $prerm->unpacked_path);

        while (my $line = <$fd>) {

            next
              if $line =~ /$EXCLUDE_R/;

            $line =~ s/\#.*$//;

            next
              unless $line =~ /update-rc\.d\s+($OPTS_R)*($INITD_NAME_REGEX)/;

            $self->hint('prerm-calls-updaterc.d', $2);
        }
        close($fd);
    }

    # init.d scripts have to be removed in postrm
    for (keys %initd_postinst) {
        if ($initd_postrm{$_}) {
            delete $initd_postrm{$_};
        } else {
            $self->hint('postrm-does-not-call-updaterc.d-for-init.d-script',
                "etc/init.d/$_");
        }
    }
    for (keys %initd_postrm) {
        $self->hint('postrm-contains-additional-updaterc.d-calls',
            "etc/init.d/$_");
    }

    foreach my $initd_file (keys %initd_postinst) {
        my $initd_path;
        $initd_path = $initd_dir->child($initd_file)
          if $initd_dir;

        # init.d scripts have to be marked as conffiles unless they're
        # symlinks.
        if (not $initd_path or not $initd_path->resolve_path) {
            my $ok = 0;
            if ($initd_path and $initd_path->is_symlink) {
                $ok = 1 if $initd_path->link eq '/lib/init/upstart-job';
            }
            if (not $ok) {
                $self->hint('init.d-script-not-included-in-package',
                    "etc/init.d/$initd_file");
            }
            next;
        }

        if (
            not $initd_path
            or (    not $processable->conffiles->is_known($initd_path->name)
                and not $initd_path->is_symlink)
        ) {
            $self->hint('init.d-script-not-marked-as-conffile',
                "etc/init.d/$initd_file");
        }

        # Check if file exists in package and check the script for
        # other issues if it was included in the package.
        $self->check_init($initd_path);
    }
    $self->check_defaults;

    return unless $initd_dir and $initd_dir->is_dir;

    # files actually installed in /etc/init.d should match our list :-)
    for my $script ($initd_dir->children) {
        my $tagname = 'script-in-etc-init.d-not-registered-via-update-rc.d';
        my $basename = $script->basename;
        next
          if (
            any {$basename eq $_}
            qw(README skeleton rc rcS)
          ) && !$script->is_dir;

        # In an upstart system, such as Ubuntu, init scripts are symlinks to
        # upstart-job which are not registered with update-rc.d.
        if ($script->is_symlink and $script->link eq '/lib/init/upstart-job') {
            $tagname
              = 'upstart-job-in-etc-init.d-not-registered-via-update-rc.d';
        }

        # If $initd_postinst is true for this script, we already
        # checked the syntax in the above loop.  Check the syntax of
        # unregistered scripts so that we get more complete Lintian
        # coverage in the first pass.
        unless ($initd_postinst{$script->basename}) {
            $self->hint($tagname, $script);
            $self->check_init($script);
        }
    }

    return;
}

sub check_init {
    my ($self, $initd_path) = @_;

    my $processable = $self->processable;

    # In an upstart system, such as Ubuntu, init scripts are symlinks to
    # upstart-job.  It doesn't make sense to check the syntax of upstart-job,
    # so skip the checks of the init script itself in that case.
    if ($initd_path->is_symlink) {
        if ($initd_path->link eq '/lib/init/upstart-job') {
            return;
        }
    }
    return if not $initd_path->is_open_ok;
    my (%tag, %lsb);
    my $in_file_test = 0;
    my $needs_fs = 0;

    open(my $fd, '<', $initd_path->unpacked_path)
      or die encode_utf8('Cannot open ' . $initd_path->unpacked_path);

    while (my $l = <$fd>) {
        if ($. == 1) {
            if ($l
                =~ m{^ [#]! \s* (?:/usr/bin/env)? \s* /lib/init/init-d-script}xsm
            ) {
                for my $arg (qw(start stop restart force-reload status)) {
                    $tag{$arg} = 1;
                }
            } elsif ($l =~ m{^\#!\s*(/usr/[^\s]+)}) {
                $self->hint('init.d-script-uses-usr-interpreter',
                    $initd_path, $1);
            }
        }
        if ($l =~ m/Please remove the "Author" lines|Example initscript/) {
            $self->hint('init.d-script-contains-skeleton-template-content',
                "${initd_path}:$.");
        }
        if ($l =~ m/^\#\#\# BEGIN INIT INFO/) {
            if ($lsb{BEGIN}) {
                $self->hint('init.d-script-has-duplicate-lsb-section',
                    $initd_path);
                next;
            }
            $lsb{BEGIN} = 1;
            my $final;

            # We have an LSB keyword section.  Parse it and save the data
            # in %lsb for analysis.
            while (my $l = <$fd>) {
                if ($l =~ /^\#\#\# END INIT INFO/) {
                    $lsb{END} = 1;
                    last;
                } elsif ($l !~ /^\#/) {
                    $self->hint('init.d-script-has-unterminated-lsb-section',
                        "${initd_path}:$.");
                    last;
                } elsif ($l =~ /^\# ([a-zA-Z-]+):\s*(.*?)\s*$/) {
                    my $keyword = lc $1;
                    my $value = $2;
                    $self->hint('init.d-script-has-duplicate-lsb-keyword',
                        "${initd_path}:$. $keyword")
                      if (defined $lsb{$keyword});
                    $self->hint(
                        'init.d-script-has-unknown-lsb-keyword',
                        "${initd_path}:$. $keyword"
                      )
                      unless (defined($lsb_keywords{$keyword})
                        || $keyword =~ /^x-/);
                    $lsb{$keyword} = defined($value) ? $value : $EMPTY;
                    $final = $keyword;
                } elsif ($l =~ /^\#(\t|  )/ && $final eq 'description') {
                    my $value = $l;
                    $value =~ s/^\#\s*//;
                    $lsb{description} .= $SPACE . $value;
                } else {
                    $self->hint('init.d-script-has-bad-lsb-line',
                        "${initd_path}:$.");
                }
            }
        }

        # Pretty dummy way to handle conditionals, but should be enough
        # for simple init scripts
        $in_file_test = 1
          if ($l =~ m/\bif\s+.*?(?:test|\[)(?:\s+\!)?\s+-[efr]\s+/);
        $in_file_test = 0 if ($l =~ m/\bfi\b/);
        if (!$in_file_test && $l =~ m{^\s*\.\s+["'"]?(/etc/default/[\$\w/-]+)})
        {
            $self->hint('init.d-script-sourcing-without-test',
                "${initd_path}:$. $1");
        }

        if ($l =~ m{\. /lib/init/init-d-script}) {
            # Some init.d scripts source init-d-script, since (e.g.)
            # kFreeBSD does not allow shell scripts as interpreters.
            for my $arg (qw(start stop restart force-reload status)) {
                $tag{$arg} = 1;
            }
        }

        # This should be more sophisticated: ignore heredocs, ignore quoted
        # text and the arguments to echo, etc.
        $needs_fs = 1 if $l =~ m{^[^\#]*/var/};

        while ($l =~ s/^[^\#]*?(start|stop|restart|force-reload|status)//) {
            $tag{$1} = 1;
        }

        if (
               $l =~ m{^\s*\.\s+/lib/lsb/init-functions}
            && !$processable->relation('strong')->satisfies('lsb-base')
            && none { $_->basename =~ m/\.service$/ && !$_->is_dir }
            @{$processable->installed->sorted_list}
        ) {
            $self->hint('init.d-script-needs-depends-on-lsb-base',
                $initd_path, "(line $.)");
        }
    }
    close($fd);

    # Make sure all of the required keywords are present.
    if (not $lsb{BEGIN}) {
        $self->hint('init.d-script-missing-lsb-section', $initd_path);
    } else {
        for my $keyword (keys %lsb_keywords) {
            if ($lsb_keywords{$keyword} && !defined $lsb{$keyword}) {
                if ($keyword eq 'short-description') {
                    $self->hint('init.d-script-missing-lsb-short-description',
                        $initd_path);
                } elsif ($keyword eq 'description') {
                    next;
                } else {
                    $self->hint('init.d-script-missing-lsb-keyword',
                        $initd_path, $keyword);
                }
            }
        }
    }

    # Check the runlevels.
    my %start;
    if (defined $lsb{'default-start'}) {
        for my $runlevel (split(/\s+/, $lsb{'default-start'})) {
            if ($runlevel =~ /^[sS0-6]$/) {
                $start{lc $runlevel} = 1;
                if ($runlevel eq '0' or $runlevel eq '6') {
                    $self->hint('init.d-script-starts-in-stop-runlevel',
                        $initd_path, $runlevel);
                }
            } else {
                $self->hint('init.d-script-has-bad-start-runlevel',
                    $initd_path, $runlevel);
            }
        }

        # No script should start at one of the 2-5 runlevels but not at
        # all of them
        my $start = join($SPACE, sort grep { /^[2-5]$/ } keys %start);
        if (length($start) > 0 and $start ne '2 3 4 5') {
            my @missing = grep { !defined $start{$_} } qw(2 3 4 5);
            $self->hint('init.d-script-missing-start', $initd_path,@missing);
        }
    }
    if (defined $lsb{'default-stop'}) {
        my %stop;
        for my $runlevel (split(/\s+/, $lsb{'default-stop'})) {
            if ($runlevel =~ /^[sS0-6]$/) {
                $stop{$runlevel} = 1 unless $runlevel =~ /[sS2-5]/;
                if ($start{$runlevel}) {
                    $self->hint('init.d-script-has-conflicting-start-stop',
                        $initd_path, $runlevel);
                }
                if ($runlevel =~ /[sS]/) {
                    $self->hint('init-d-script-stops-in-s-runlevel',
                        $initd_path);
                }
            } else {
                $self->hint('init.d-script-has-bad-stop-runlevel',
                    $initd_path, $runlevel);
            }
        }

        # Scripts that stop in any of 0, 1, or 6 probably should stop in all
        # of them, with some special exceptions.
        my $stop = join($SPACE, sort keys %stop);
        if (length($stop) > 0 and $stop ne '0 1 6') {
            my $base = $initd_path->basename;
            if (none { $base eq $_ } qw(killprocs sendsigs halt reboot)) {
                my @missing = grep { !defined $stop{$_} } qw(0 1 6);
                my $start = join($SPACE, sort keys %start);
                $self->hint('init.d-script-possible-missing-stop',
                    $initd_path,@missing)
                  unless $start eq 's';
            }
        }
    }
    if ($lsb{'provides'}) {
        my $provides_self;
        for my $facility (split(/\s+/, $lsb{'provides'})) {
            if ($facility =~ /^\$/) {
                $self->hint('init.d-script-provides-virtual-facility',
                    $initd_path, $facility);
            }
            if ($initd_path->basename =~/^\Q$facility\E(?:.sh)?$/) {
                $provides_self = 1;
            }
        }
        $self->hint('init.d-script-does-not-provide-itself', $initd_path)
          unless $provides_self;
    }

    # Separately check Required-Start and Required-Stop, since while they're
    # similar, they're not quite identical.  This could use some further
    # restructuring by pulling the regexes out as data tied to start/stop and
    # remote/local and then combining the loops.
    if (defined $lsb{'default-start'} && length($lsb{'default-start'})) {
        my @required = split($SPACE, $lsb{'required-start'} || $EMPTY);
        if ($needs_fs) {
            if (none { /^\$(?:local_fs|remote_fs|all)\z/ } @required) {
                $self->hint('init.d-script-missing-dependency-on-local_fs',
                    "${initd_path}: required-start");
            }
        }
    }
    if (defined $lsb{'default-stop'} && length($lsb{'default-stop'})) {
        my @required = split($SPACE, $lsb{'required-stop'} || $EMPTY);
        if ($needs_fs) {
            if (
                none { /^(?:\$(?:local|remote)_fs|\$all|umountn?fs)\z/ }
                @required
            ) {
                $self->hint('init.d-script-missing-dependency-on-local_fs',
                    "${initd_path}: required-stop");
            }
        }
    }

    my $VIRTUAL_FACILITIES
      = $self->profile->load_data('init.d/virtual_facilities');

    # Check syntax rules that apply to all of the keywords.
    for my $keyword (qw(required-start should-start required-stop should-stop))
    {
        next unless defined $lsb{$keyword};
        for my $dependency (split(/\s+/, $lsb{$keyword})) {
            if (defined $implied_dependencies{$dependency}) {
                $self->hint('non-virtual-facility-in-initd-script',
                    $initd_path,
                    "$dependency -> $implied_dependencies{$dependency}");
            } elsif ($keyword =~ m/^required-/ && $dependency =~ m/^\$/) {
                $self->hint(
                    'init.d-script-depends-on-unknown-virtual-facility',
                    $initd_path, $dependency)
                  unless ($VIRTUAL_FACILITIES->recognizes($dependency));
            }
            if ($dependency =~ m/^\$all$/) {
                $self->hint('init.d-script-depends-on-all-virtual-facility',
                    $initd_path, $keyword);
            }
        }
    }

    # all tags included in file?
    for my $option (qw(start stop restart force-reload)) {
        $tag{$option}
          or $self->hint('init.d-script-does-not-implement-required-option',
            $initd_path, $option);
    }

    $self->hint('init.d-script-does-not-implement-status-option', $initd_path)
      unless $tag{'status'};

    return;
}

sub check_defaults {
    my ($self) = @_;

    my $processable = $self->processable;

    my $dir = $processable->installed->resolve_path('etc/default/');
    return unless $dir and $dir->is_dir;
    for my $path ($dir->children) {

        return
          unless $path->is_open_ok;

        open(my $fd, '<', $path->unpacked_path)
          or die encode_utf8('Cannot open ' . $path->unpacked_path);

        while (my $line = <$fd>) {
            $self->hint('init.d-script-should-always-start-service',
                $path, "(line $.)")
              if $line =~ /$ALWAYS_START/;
        }
        close($fd);
    }
    return;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    # check for missing init.d script when alternative init system is present

    if (   $item =~ m{etc/sv/(?<svc>[^/]+)/run$}
        || $item =~ m{(?<usr>usr/)?lib/systemd/system/(?<svc>[^/@]+)\.service})
    {

        my ($usr, $service) = ($+{usr} // $EMPTY, $+{svc});

        $self->hint('package-supports-alternative-init-but-no-init.d-script',
            $item)
          unless $self->processable->installed->resolve_path(
            "etc/init.d/${service}")
          or $self->processable->installed->resolve_path(
            "${usr}lib/systemd/system/${service}.path")
          or $self->processable->installed->resolve_path(
            "${usr}lib/systemd/system/${service}.timer");
    }

    if ($item =~ m{etc/sv/([^/]+)/$}) {

        my $service = $1;
        my $runfile
          = $self->processable->installed->resolve_path(
            "etc/sv/${service}/run");

        $self->hint(
            'directory-in-etc-sv-directory-without-executable-run-script',
            $runfile)
          if not $runfile or not $runfile->is_executable;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
