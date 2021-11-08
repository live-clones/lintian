# systemd -- lintian check script -*- perl -*-
#
# Copyright © 2013 Michael Stapelberg
# Copyright © 2016-2020 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
#
# based on the apache2 checks file by:
# Copyright © 2012 Arno Töll
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

package Lintian::Check::Systemd;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Data::Validate::URI qw(is_uri);
use List::Compare;
use List::SomeUtils qw(any none);
use Text::ParseWords qw(shellwords);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

# "Usual" targets for WantedBy
const my @WANTEDBY_WHITELIST => qw{
  default.target
  graphical.target
  multi-user.target
  network-online.target
  sleep.target
  sysinit.target
};

# Known hardening flags in [Service] section
const my @HARDENING_FLAGS => qw{
  CapabilityBoundingSet
  DeviceAllow
  DynamicUser
  IPAddressDeny
  InaccessiblePaths
  KeyringMode
  LimitNOFILE
  LockPersonality
  MemoryDenyWriteExecute
  MountFlags
  NoNewPrivileges
  PrivateDevices
  PrivateMounts
  PrivateNetwork
  PrivateTmp
  PrivateUsers
  ProtectControlGroups
  ProtectHome
  ProtectHostname
  ProtectKernelLogs
  ProtectKernelModules
  ProtectKernelTunables
  ProtectSystem
  ReadOnlyPaths
  RemoveIPC
  RestrictAddressFamilies
  RestrictNamespaces
  RestrictRealtime
  RestrictSUIDSGID
  SystemCallArchitectures
  SystemCallFilter
  UMask
};

# init scripts that do not need a service file
has PROVIDED_BY_SYSTEMD => (
    is => 'rw',
    lazy => 1,
    default =>sub {
        my ($self) = @_;

        return $self->profile->load_data('systemd/init-whitelist');
    });

# array of names provided by the service files.
# This includes Alias= directives, so after parsing
# NetworkManager.service, it will contain NetworkManager and
# network-manager.
has service_names => (is => 'rw', default => sub { [] });

has timer_files => (is => 'rw', default => sub { [] });

has init_files_by_service_name => (is => 'rw', default => sub { {} });
has cron_scripts => (is => 'rw', default => sub { [] });

has is_rcs_script_by_name => (is => 'rw', default => sub { {} });

sub visit_installed_files {
    my ($self, $item) = @_;

    if ($item->name =~ m{/systemd/system/.*\.service$}) {

        $self->check_systemd_service_file($item);

        my $service_name = $item->basename;
        $service_name =~ s/@?\.service$//;

        push(@{$self->service_names}, $service_name);

        my @aliases
          = $self->extract_service_file_values($item, 'Install', 'Alias');

        for my $alias (@aliases) {

            $self->hint('systemd-service-alias-without-extension', $item->name)
              if $alias !~ m/\.service$/;

            # maybe issue a tag for duplicates?

            $alias =~ s{ [.]service $}{}x;
            push(@{$self->service_names}, $alias);
        }
    }

    push(@{$self->timer_files}, $item)
      if $item->name =~ m{^(?:usr/)?lib/systemd/system/[^\/]+\.timer$};

    push(@{$self->cron_scripts}, $item)
      if $item->dirname =~ m{^ etc/cron[.][^\/]+ / $}x;

    if (   $item->dirname eq 'etc/init.d/'
        && !$item->is_dir
        && (none { $item->basename eq $_} qw{README skeleton rc rcS})
        && $self->processable->name ne 'initscripts'
        && $item->link ne 'lib/init/upstart-job') {

        unless ($item->is_file) {

            $self->hint('init-script-is-not-a-file', $item->name);
            return;
        }

        # sysv generator drops the .sh suffix
        my $service_name = $item->basename;
        $service_name =~ s{ [.]sh $}{}x;

        $self->init_files_by_service_name->{$service_name} //= [];
        push(@{$self->init_files_by_service_name->{$service_name}}, $item);

        $self->is_rcs_script_by_name->{$item->name}
          = $self->check_init_script($item);
    }

    if ($item->name =~ m{ /systemd/system/ .*[.]socket $}x) {

        my @values
          = $self->extract_service_file_values($item,'Socket','ListenStream');

        $self->hint('systemd-service-file-refers-to-var-run',
            $item, 'ListenStream', $_)
          for grep { m{^/var/run/} } @values;
    }

    return;
}

sub installable {
    my ($self) = @_;

    my $lc = List::Compare->new([keys %{$self->init_files_by_service_name}],
        $self->service_names);

    my @missing_service_names = $lc->get_Lonly;

    for my $service_name (@missing_service_names) {

        next
          if $self->PROVIDED_BY_SYSTEMD->recognizes($service_name);

        my @init_files
          = @{$self->init_files_by_service_name->{$service_name} // []};

        for my $init_file (@init_files) {

            # rcS scripts are particularly bad; always tag
            $self->hint('missing-systemd-service-for-init.d-rcS-script',
                $init_file->name, $service_name)
              if $self->is_rcs_script_by_name->{$init_file->name};

            $self->hint('omitted-systemd-service-for-init.d-script',
                $init_file->name, $service_name)
              if @{$self->service_names}
              && !$self->is_rcs_script_by_name->{$init_file->name};

            $self->hint('missing-systemd-service-for-init.d-script',
                $init_file->name, $service_name)
              if !@{$self->service_names}
              && !$self->is_rcs_script_by_name->{$init_file->name};
        }
    }

    if (!@{$self->timer_files}) {

        $self->hint('missing-systemd-timer-for-cron-script', $_->name)
          for @{$self->cron_scripts};
    }

    return;
}

# Verify that each init script includes /lib/lsb/init-functions,
# because that is where the systemd diversion happens.
sub check_init_script {
    my ($self, $item) = @_;

    my $lsb_source_seen;
    my $is_rcs_script = 0;

    my @lines = split(/\n/, $item->decoded_utf8);

    my $position = 1;
    for my $line (@lines) {

        # trim left
        $line =~ s/^\s+//;

        $lsb_source_seen = 1
          if $position == 1
          && $line
          =~ m{\A [#]! \s* (?:/usr/bin/env)? \s* /lib/init/init-d-script}xsm;

        $is_rcs_script = 1
          if $line =~ m{#.*Default-Start:.*S};

        next
          if $line =~ /^#/;

        $lsb_source_seen = 1
          if $line
          =~ m{(?:\.|source)\s+/lib/(?:lsb/init-functions|init/init-d-script)};

    } continue {
        ++$position;
    }

    $self->hint('init.d-script-does-not-source-init-functions', $item)
      unless $lsb_source_seen;

    return $is_rcs_script;
}

sub check_systemd_service_file {
    my ($self, $item) = @_;

    # ambivalent about /lib or /usr/lib
    $self->hint('systemd-service-in-odd-location', $item)
      if $item =~ m{^etc/systemd/system/};

    unless ($item->is_open_ok
        || ($item->is_symlink && $item->link eq '/dev/null')) {

        $self->hint('service-file-is-not-a-file', $item);
        return 0;
    }

    my @values = $self->extract_service_file_values($item, 'Unit', 'After');
    my @obsolete = grep { /^(?:syslog|dbus)\.target$/ } @values;

    $self->hint('systemd-service-file-refers-to-obsolete-target',$item, $_)
      for @obsolete;

    $self->hint('systemd-service-file-refers-to-obsolete-bindto', $item)
      if $self->extract_service_file_values($item, 'Unit', 'BindTo');

    for my $key (
        qw(ExecStart ExecStartPre ExecStartPost ExecReload ExecStop ExecStopPost)
    ) {
        $self->hint('systemd-service-file-wraps-init-script', $item, $key)
          if any { m{^/etc/init\.d/} }
        $self->extract_service_file_values($item, 'Service', $key);
    }

    unless ($item->link eq '/dev/null') {

        my @wanted_by
          = $self->extract_service_file_values($item, 'Install', 'WantedBy');
        my $is_oneshot = any { $_ eq 'oneshot' }
        $self->extract_service_file_values($item, 'Service', 'Type');

        # We are a "standalone" service file if we have no .path or .timer
        # equivalent.
        my $is_standalone = 1;
        if ($item =~ m{^(usr/)?lib/systemd/system/([^/]*?)@?\.service$}) {

            my ($usr, $service) = ($1 // $EMPTY, $2);

            $is_standalone = 0
              if $self->processable->installed->resolve_path(
                "${usr}lib/systemd/system/${service}.path")
              || $self->processable->installed->resolve_path(
                "${usr}lib/systemd/system/${service}.timer");
        }

        for my $target (@wanted_by) {

            $self->hint(
                'systemd-service-file-refers-to-unusual-wantedby-target',
                $item, $target)
              unless (any { $target eq $_ } @WANTEDBY_WHITELIST)
              || $self->processable->name eq 'systemd';
        }

        my @documentation
          = $self->extract_service_file_values($item, 'Unit','Documentation');

        $self->hint('systemd-service-file-missing-documentation-key', $item)
          unless @documentation;

        for my $documentation (@documentation) {

            my @uris = split(m{\s+}, $documentation);

            my @invalid = grep { !is_uri($_) } @uris;

            $self->hint('invalid-systemd-documentation',
                $_,$LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET)
              for @invalid;
        }

        my @kill_modes
          = $self->extract_service_file_values($item, 'Service','KillMode');

        for my $kill_mode (@kill_modes) {

            # trim both ends
            $kill_mode =~ s/^\s+|\s+$//g;

            $self->hint('kill-mode-none',$_,
                $LEFT_SQUARE_BRACKET . $item->name . $RIGHT_SQUARE_BRACKET)
              if $kill_mode eq 'none';
        }

        if (   !@wanted_by
            && !$is_oneshot
            && $is_standalone
            && $item =~ m{^(?:usr/)?lib/systemd/[^\/]+/[^\/]+\.service$}
            && $item !~ m{@\.service$}) {

            $self->hint('systemd-service-file-missing-install-key', $item)
              unless $self->extract_service_file_values($item, 'Install',
                'RequiredBy')
              || $self->extract_service_file_values($item, 'Install', 'Also');
        }

        my @pidfile
          = $self->extract_service_file_values($item,'Service','PIDFile');
        for my $x (@pidfile) {
            $self->hint('systemd-service-file-refers-to-var-run',
                $item, 'PIDFile', $x)
              if $x =~ m{^/var/run/};
        }

        my $seen_hardening
          = any { $self->extract_service_file_values($item, 'Service', $_) }
        @HARDENING_FLAGS;

        $self->hint('systemd-service-file-missing-hardening-features', $item)
          unless $seen_hardening
          || $is_oneshot
          || any { 'sleep.target' eq $_ } @wanted_by;

        if (
            $self->extract_service_file_values(
                $item, 'Unit', 'DefaultDependencies', 1
            )
        ) {
            my @before
              = $self->extract_service_file_values($item, 'Unit','Before');
            my @conflicts
              = $self->extract_service_file_values($item, 'Unit','Conflicts');

            $self->hint('systemd-service-file-shutdown-problems', $item)
              if (none { $_ eq 'shutdown.target' } @before)
              && (any { $_ eq 'shutdown.target' } @conflicts);
        }

        my %bad_users = (
            'User' => 'nobody',
            'Group' => 'nogroup',
        );

        for my $key (keys %bad_users) {

            my $value = $bad_users{$key};

            $self->hint('systemd-service-file-uses-nobody-or-nogroup',
                $item, "$key=$value")
              if any { $_ eq $value }
            $self->extract_service_file_values($item, 'Service',$key);
        }

        for my $key (qw(StandardError StandardOutput)) {
            for my $value (qw(syslog syslog-console)) {

                $self->hint(
                    'systemd-service-file-uses-deprecated-syslog-facility',
                    $item, "$key=$value")
                  if any { $_ eq $value }
                $self->extract_service_file_values($item, 'Service',$key);
            }
        }
    }

    return 1;
}

sub service_file_lines {
    my ($item) = @_;

    my @output;

    return @output
      if $item->is_symlink and $item->link eq '/dev/null';

    my @lines = split(/\n/, $item->decoded_utf8);
    my $continuation = $EMPTY;

    my $position = 1;
    for my $line (@lines) {

        $line = $continuation . $line;
        $continuation = $EMPTY;

        if ($line =~ s/\\$/ /) {
            $continuation = $line;
            next;
        }

        # trim right
        $line =~ s/\s+$//;

        next
          unless length $line;

        next
          if $line =~ /^[#;\n]/;

        push(@output, $line);
    }

    return @output;
}

# Extracts the values of a specific Key from a .service file
sub extract_service_file_values {
    my ($self, $item, $extract_section, $extract_key) = @_;

    return ()
      unless length $extract_section && length $extract_key;

    my @values;
    my $section;

    my @lines = service_file_lines($item);
    for my $line (@lines) {
        # section header
        if ($line =~ /^\[([^\]]+)\]$/) {
            $section = $1;
            next;
        }

        if (!defined($section)) {
            # Assignment outside of section. Ignoring.
            next;
        }

        my ($key, $value) = ($line =~ m{^(.*)\s*=\s*(.*)$});
        if (   defined($key)
            && $section eq $extract_section
            && $key eq $extract_key) {

            if (length $value) {
                push(@values, shellwords($value));

            } else {
                # Empty assignment resets the list
                @values = ();
            }
        }
    }

    return @values;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
