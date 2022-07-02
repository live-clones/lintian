# init.d -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz
# Copyright (C) 2016-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2021 Felix Lechner
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::InitD;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename qw(dirname);
use List::Compare;
use List::SomeUtils qw(any none);
use Unicode::UTF8 qw(encode_utf8);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $DOLLAR => q{$};

const my $RUN_LEVEL_6 => 6;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# A list of valid LSB keywords.  The value is 0 if optional and 1 if required.
my %LSB_KEYWORDS = (
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
    'mountall'   => $DOLLAR . 'local_fs',
    'mountnfs'   => $DOLLAR . 'remote_fs',

    'hwclock'    => $DOLLAR . 'time',
    'portmap'    => $DOLLAR . 'portmap',
    'named'      => $DOLLAR . 'named',
    'bind9'      => $DOLLAR . 'named',
    'networking' => $DOLLAR . 'network',
    'syslog'     => $DOLLAR . 'syslog',
    'rsyslog'    => $DOLLAR . 'syslog',
    'sysklogd'   => $DOLLAR . 'syslog'
);

# Regex to match names of init.d scripts; it is a bit more lax than
# package names (e.g. allows "_").  We do not allow it to start with a
# "dash" to avoid confusing it with a command-line option (also,
# update-rc.d does not allow this).
our $INITD_NAME_REGEX = qr/[\w\.\+][\w\-\.\+]*/;

my $OPTS_R = qr/-\S+\s*/;
my $ACTION_R = qr/\w+/;
my $EXCLUDE_R = qr/if\s+\[\s+-x\s+\S*update-rc\.d/;

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
    return
      if $pkg eq 'initscripts'
      || $pkg eq 'sysvinit';

    # read postinst control file
    if ($postinst and $postinst->is_file and $postinst->is_open_ok) {

        open(my $fd, '<', $postinst->unpacked_path)
          or die encode_utf8('Cannot open ' . $postinst->unpacked_path);

        my $position = 1;
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

            my $pointer = $postinst->pointer($position);

            if ($initd_postinst{$name}++ == 1) {

                $self->pointed_hint('duplicate-updaterc.d-calls-in-postinst',
                    $pointer, $name);
                next;
            }

            $self->pointed_hint(
                'output-of-updaterc.d-not-redirected-to-dev-null',
                $pointer, $name)
              unless $line =~ m{>\s*/dev/null};

        } continue {
            ++$position;
        }

        close $fd;
    }

    # read preinst control file
    if ($preinst and $preinst->is_file and $preinst->is_open_ok) {

        open(my $fd, '<', $preinst->unpacked_path)
          or die encode_utf8('Cannot open ' . $preinst->unpacked_path);

        my $position = 1;
        while (my $line = <$fd>) {

            next
              if $line =~ /$EXCLUDE_R/;

            $line =~ s/\#.*$//;
            next
              unless $line =~ m{update-rc\.d \s+
                       (?:$OPTS_R)*($INITD_NAME_REGEX) \s+
                       ($ACTION_R)}x;

            my $name = $1;
            my $option = $2;
            next
              if $option eq 'remove';

            my $pointer = $preinst->pointer($position);

            $self->pointed_hint('preinst-calls-updaterc.d',
                $pointer, $name, $option);

        } continue {
            ++$position;
        }

        close $fd;
    }

    # read postrm control file
    if ($postrm and $postrm->is_file and $postrm->is_open_ok) {

        open(my $fd, '<', $postrm->unpacked_path)
          or die encode_utf8('Cannot open ' . $postrm->unpacked_path);

        my $position = 1;
        while (my $line = <$fd>) {

            next
              if $line =~ /$EXCLUDE_R/;

            $line =~ s/\#.*$//;

            next
              unless $line =~ /update-rc\.d\s+(?:$OPTS_R)*($INITD_NAME_REGEX)/;

            my $name = $1;

            my $pointer = $postrm->pointer($position);

            if ($initd_postrm{$name}++ == 1) {

                $self->pointed_hint('duplicate-updaterc.d-calls-in-postrm',
                    $pointer, $name);
                next;
            }

            $self->pointed_hint(
                'output-of-updaterc.d-not-redirected-to-dev-null',
                $pointer, $name)
              unless $line =~ m{>\s*/dev/null};

        } continue {
            ++$position;
        }

        close $fd;
    }

    # read prerm control file
    if ($prerm and $prerm->is_file and $prerm->is_open_ok) {

        open(my $fd, '<', $prerm->unpacked_path)
          or die encode_utf8('Cannot open ' . $prerm->unpacked_path);

        my $position = 1;
        while (my $line = <$fd>) {

            next
              if $line =~ /$EXCLUDE_R/;

            $line =~ s/\#.*$//;

            next
              unless $line =~ /update-rc\.d\s+(?:$OPTS_R)*($INITD_NAME_REGEX)/;

            my $name = $1;

            my $pointer = $prerm->pointer($position);

            $self->pointed_hint('prerm-calls-updaterc.d', $pointer, $name);

        } continue {
            ++$position;
        }

        close $fd;
    }

    # init.d scripts have to be removed in postrm
    for (keys %initd_postinst) {
        if ($initd_postrm{$_}) {
            delete $initd_postrm{$_};
        } else {

            $self->pointed_hint(
                'postrm-does-not-call-updaterc.d-for-init.d-script',
                $postrm->pointer, "etc/init.d/$_");
        }
    }

    for (keys %initd_postrm) {
        $self->pointed_hint('postrm-contains-additional-updaterc.d-calls',
            $postrm->pointer, "etc/init.d/$_");
    }

    for my $initd_file (keys %initd_postinst) {

        my $item;
        $item = $initd_dir->child($initd_file)
          if $initd_dir;

        unless (
            (defined $item && $item->resolve_path)
            ||(    defined $item
                && $item->is_symlink
                && $item->link eq '/lib/init/upstart-job')
        ) {

            $self->hint('init.d-script-not-included-in-package',
                "etc/init.d/$initd_file");

            next;
        }

        # init.d scripts have to be marked as conffiles unless they're
        # symlinks.
        $self->hint('init.d-script-not-marked-as-conffile',
            "etc/init.d/$initd_file")
          if !defined $item
          || ( !$processable->declared_conffiles->is_known($item->name)
            && !$item->is_symlink);

        # Check if file exists in package and check the script for
        # other issues if it was included in the package.
        $self->check_init($item);
    }
    $self->check_defaults;

    return
      unless defined $initd_dir && $initd_dir->is_dir;

    # files actually installed in /etc/init.d should match our list :-)
    for my $script ($initd_dir->children) {

        next
          if !$script->is_dir
          && (any {$script->basename eq $_}qw(README skeleton rc rcS));

        my $tag_name = 'script-in-etc-init.d-not-registered-via-update-rc.d';

        # In an upstart system, such as Ubuntu, init scripts are symlinks to
        # upstart-job which are not registered with update-rc.d.
        $tag_name= 'upstart-job-in-etc-init.d-not-registered-via-update-rc.d'
          if $script->is_symlink
          && $script->link eq '/lib/init/upstart-job';

        # If $initd_postinst is true for this script, we already
        # checked the syntax in the above loop.  Check the syntax of
        # unregistered scripts so that we get more complete Lintian
        # coverage in the first pass.
        unless ($initd_postinst{$script->basename}) {

            $self->pointed_hint($tag_name, $script->pointer);
            $self->check_init($script);
        }
    }

    return;
}

sub check_init {
    my ($self, $item) = @_;

    my $processable = $self->processable;

    # In an upstart system, such as Ubuntu, init scripts are symlinks to
    # upstart-job.  It doesn't make sense to check the syntax of upstart-job,
    # so skip the checks of the init script itself in that case.
    return
      if $item->is_symlink
      && $item->link eq '/lib/init/upstart-job';

    return
      unless $item->is_open_ok;

    my %saw_command;
    my %value_by_lsb_keyword;
    my $in_file_test = 0;
    my $needs_fs = 0;

    if ($item->interpreter eq '/lib/init/init-d-script') {
        $saw_command{$_} = 1 for qw{start stop restart force-reload status};
    }

    $self->pointed_hint('init.d-script-uses-usr-interpreter',
        $item->pointer(1), $item->interpreter)
      if $item->interpreter =~ m{^ /usr/ }x;

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $position = 1;
    while (my $line = <$fd>) {

        $self->pointed_hint('init.d-script-contains-skeleton-template-content',
            $item->pointer($position))
          if $line =~ m{Please remove the "Author" lines|Example initscript};

        if ($line =~ m/^\#\#\# BEGIN INIT INFO/) {

            if (defined $value_by_lsb_keyword{BEGIN}) {

                $self->pointed_hint('init.d-script-has-duplicate-lsb-section',
                    $item->pointer($position));
                next;
            }

            $value_by_lsb_keyword{BEGIN} = [1];
            my $final;

            # We have an LSB keyword section.  Parse it and save the data
            # in %value_by_lsb_keyword for analysis.
            while (my $other_line = <$fd>) {

                # nested while
                ++$position;

                if ($other_line =~ /^\#\#\# END INIT INFO/) {
                    $value_by_lsb_keyword{END} = [1];
                    last;

                } elsif ($other_line !~ /^\#/) {
                    $self->pointed_hint(
                        'init.d-script-has-unterminated-lsb-section',
                        $item->pointer($position));
                    last;

                } elsif ($other_line =~ /^\# ([a-zA-Z-]+):\s*(.*?)\s*$/) {

                    my $keyword = lc $1;
                    my $value = $2 // $EMPTY;

                    $self->pointed_hint(
                        'init.d-script-has-duplicate-lsb-keyword',
                        $item->pointer($position), $keyword)
                      if defined $value_by_lsb_keyword{$keyword};

                    $self->pointed_hint(
                        'init.d-script-has-unknown-lsb-keyword',
                        $item->pointer($position), $keyword)
                      unless exists $LSB_KEYWORDS{$keyword}
                      || $keyword =~ /^x-/;

                    $value_by_lsb_keyword{$keyword} = [split($SPACE, $value)];
                    $final = $keyword;

                } elsif ($other_line =~ /^\#(\t|  )/
                    && $final eq 'description') {

                    my $value = $other_line;
                    $value =~ s/^\#\s*//;
                    $value_by_lsb_keyword{description} .= $SPACE . $value;

                } else {
                    $self->pointed_hint('init.d-script-has-bad-lsb-line',
                        $item->pointer($position));
                }
            }
        }

        # Pretty dummy way to handle conditionals, but should be enough
        # for simple init scripts
        $in_file_test = 1
          if $line
          =~ m{ \b if \s+ .*? (?:test|\[) (?: \s+ \! )? \s+ - [efr] \s+ }x;

        $in_file_test = 0
          if $line =~ m{ \b fi \b }x;

        if (  !$in_file_test
            && $line =~ m{^\s*\.\s+["'"]?(/etc/default/[\$\w/-]+)}){
            my $sourced = $1;

            $self->pointed_hint('init.d-script-sourcing-without-test',
                $item->pointer($position), $sourced);
        }

        # Some init.d scripts source init-d-script, since (e.g.)
        # kFreeBSD does not allow shell scripts as interpreters.
        if ($line =~ m{\. /lib/init/init-d-script}) {
            $saw_command{$_} = 1
              for qw{start stop restart force-reload status};
        }

        # This should be more sophisticated: ignore heredocs, ignore quoted
        # text and the arguments to echo, etc.
        $needs_fs = 1
          if $line =~ m{^[^\#]*/var/};

        while ($line =~ s/^[^\#]*?(start|stop|restart|force-reload|status)//) {
            $saw_command{$1} = 1;
        }

        if (
            $line =~ m{^\s*\.\s+/lib/lsb/init-functions}
            && !$processable->relation('strong')->satisfies('lsb-base:any')
            && (none { $_->basename =~ m/\.service$/ && !$_->is_dir }
                @{$processable->installed->sorted_list})
        ) {
            $self->pointed_hint('init.d-script-needs-depends-on-lsb-base',
                $item->pointer($position));
        }

        # nested while
    } continue {
        ++$position;
    }

    close $fd;

    # Make sure all of the required keywords are present.
    if (!defined $value_by_lsb_keyword{BEGIN}) {
        $self->pointed_hint('init.d-script-missing-lsb-section',
            $item->pointer);

    } else {
        for my $keyword (keys %LSB_KEYWORDS) {

            if ($LSB_KEYWORDS{$keyword}
                && !defined $value_by_lsb_keyword{$keyword}) {

                if ($keyword eq 'short-description') {
                    $self->pointed_hint(
                        'init.d-script-missing-lsb-short-description',
                        $item->pointer);

                } elsif ($keyword eq 'description') {
                    next;

                } else {
                    $self->pointed_hint('init.d-script-missing-lsb-keyword',
                        $item->pointer, $keyword);
                }
            }
        }
    }

    # Check the runlevels.
    my %start;

    for my $runlevel (@{$value_by_lsb_keyword{'default-start'} // []}) {

        if ($runlevel =~ /^[sS0-6]$/) {

            $start{lc $runlevel} = 1;

            $self->pointed_hint('init.d-script-starts-in-stop-runlevel',
                $item->pointer, $runlevel)
              if $runlevel eq '0'
              || $runlevel eq '6';

        } else {
            $self->pointed_hint('init.d-script-has-bad-start-runlevel',
                $item->pointer, $runlevel);
        }
    }

    # No script should start at one of the 2-5 runlevels but not at
    # all of them
    my $start = join($SPACE, (sort grep { /^[2-5]$/ } keys %start));

    if (length($start) > 0 and $start ne '2 3 4 5') {
        my @missing = grep { !exists $start{$_} } qw(2 3 4 5);

        $self->pointed_hint('init.d-script-missing-start', $item->pointer,
            @missing);
    }

    my %stop;

    for my $runlevel (@{$value_by_lsb_keyword{'default-stop'} // []}) {

        if ($runlevel =~ /^[sS0-6]$/) {

            $stop{$runlevel} = 1
              unless $runlevel =~ /[sS2-5]/;

            $self->pointed_hint('init.d-script-has-conflicting-start-stop',
                $item->pointer, $runlevel)
              if exists $start{$runlevel};

            $self->pointed_hint('init-d-script-stops-in-s-runlevel',
                $item->pointer)
              if $runlevel =~ /[sS]/;

        } else {
            $self->pointed_hint('init.d-script-has-bad-stop-runlevel',
                $item->pointer, $runlevel);
        }
    }

    if (none { $item->basename eq $_ } qw(killprocs sendsigs halt reboot)) {

        my @required = (0, 1, $RUN_LEVEL_6);
        my $stop_lc = List::Compare->new(\@required, [keys %stop]);

        my @have_some = $stop_lc->get_intersection;
        my @missing = $stop_lc->get_Lonly;

        # Scripts that stop in any of 0, 1, or 6 probably should stop in all
        # of them, with some special exceptions.
        $self->pointed_hint('init.d-script-possible-missing-stop',
            $item->pointer, (sort @missing))
          if @have_some
          && @missing
          && (%start != 1 || !exists $start{s});
    }

    my $provides_self = 0;
    for my $facility (@{$value_by_lsb_keyword{'provides'} // []}) {

        $self->pointed_hint('init.d-script-provides-virtual-facility',
            $item->pointer, $facility)
          if $facility =~ /^\$/;

        $provides_self = 1
          if $item->basename =~/^\Q$facility\E(?:.sh)?$/;
    }

    $self->pointed_hint('init.d-script-does-not-provide-itself',$item->pointer)
      if defined $value_by_lsb_keyword{'provides'}
      && !$provides_self;

    # Separately check Required-Start and Required-Stop, since while they're
    # similar, they're not quite identical.  This could use some further
    # restructuring by pulling the regexes out as data tied to start/stop and
    # remote/local and then combining the loops.
    if (@{$value_by_lsb_keyword{'default-start'} // []}) {

        my @required = @{$value_by_lsb_keyword{'required-start'} // []};

        if ($needs_fs) {
            if (none { /^\$(?:local_fs|remote_fs|all)\z/ } @required) {

                $self->pointed_hint(
                    'init.d-script-missing-dependency-on-local_fs',
                    $item->pointer, 'required-start');
            }
        }
    }

    if (@{$value_by_lsb_keyword{'default-stop'} // []}) {

        my @required = @{$value_by_lsb_keyword{'required-stop'} // []};

        if ($needs_fs) {
            if (none { /^(?:\$(?:local|remote)_fs|\$all|umountn?fs)\z/ }
                @required) {

                $self->pointed_hint(
                    'init.d-script-missing-dependency-on-local_fs',
                    $item->pointer, 'required-stop');
            }
        }
    }

    my $VIRTUAL_FACILITIES= $self->data->virtual_initd_facilities;

    # Check syntax rules that apply to all of the keywords.
    for
      my $keyword (qw(required-start should-start required-stop should-stop)){
        for my $prerequisite (@{$value_by_lsb_keyword{$keyword} // []}) {

            if (exists $implied_dependencies{$prerequisite}) {

                $self->pointed_hint('non-virtual-facility-in-initd-script',
                    $item->pointer,
                    "$prerequisite -> $implied_dependencies{$prerequisite}");

            } elsif ($keyword =~ m/^required-/ && $prerequisite =~ m/^\$/) {

                $self->pointed_hint(
                    'init.d-script-depends-on-unknown-virtual-facility',
                    $item->pointer, $prerequisite)
                  unless ($VIRTUAL_FACILITIES->recognizes($prerequisite));
            }

            $self->pointed_hint(
                'init.d-script-depends-on-all-virtual-facility',
                $item->pointer, $keyword)
              if $prerequisite =~ m/^\$all$/;
        }
    }

    my @required_commands = qw{start stop restart force-reload};
    my $command_lc
      = List::Compare->new(\@required_commands, [keys %saw_command]);
    my @missing_commands = $command_lc->get_Lonly;

    # all tags included in file?
    $self->pointed_hint('init.d-script-does-not-implement-required-option',
        $item->pointer, $_)
      for @missing_commands;

    $self->pointed_hint('init.d-script-does-not-implement-status-option',
        $item->pointer)
      unless $saw_command{'status'};

    return;
}

sub check_defaults {
    my ($self) = @_;

    my $processable = $self->processable;

    my $dir = $processable->installed->resolve_path('etc/default/');
    return
      unless $dir && $dir->is_dir;

    for my $item ($dir->children) {

        return
          unless $item->is_open_ok;

        open(my $fd, '<', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        my $position = 1;
        while (my $line = <$fd>) {

            $self->pointed_hint('init.d-script-should-always-start-service',
                $item->pointer($position))
              if $line
              =~ m{^ \s* [#]* \s* (?:[A-Z]_)? (?:ENABLED|DISABLED|[A-Z]*RUN | (?:NO_)? START) = }x;

        } continue {
            ++$position;
        }

        close $fd;
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

        $self->pointed_hint(
            'package-supports-alternative-init-but-no-init.d-script',
            $item->pointer)
          unless $self->processable->installed->resolve_path(
            "etc/init.d/${service}")
          || $self->processable->installed->resolve_path(
            "${usr}lib/systemd/system/${service}.path")
          || $self->processable->installed->resolve_path(
            "${usr}lib/systemd/system/${service}.timer");
    }

    if ($item =~ m{etc/sv/([^/]+)/$}) {

        my $service = $1;
        my $runfile
          = $self->processable->installed->resolve_path(
            "etc/sv/${service}/run");

        $self->pointed_hint(
            'directory-in-etc-sv-directory-without-executable-run-script',
            $item->pointer, $runfile)
          unless defined $runfile && $runfile->is_executable;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
