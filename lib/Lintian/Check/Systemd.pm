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
use File::Basename;
use List::SomeUtils qw(any none first_index);
use Text::ParseWords qw(shellwords);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

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
has INIT_WHITELIST => (
    is => 'rw',
    lazy => 1,
    default =>sub {
        my ($self) = @_;

        return $self->profile->load_data('systemd/init-whitelist');
    });

has services => (is => 'rw', default => sub { {} });
has timers => (is => 'rw', default => sub { [] });

sub setup_installed_files {
    my ($self) = @_;

    # A hash of names reference which are provided by the service files.
    # This includes Alias= directives, so after parsing
    # NetworkManager.service, it will contain NetworkManager and
    # network-manager.

    my @service_files = grep {
             $_->name =~ m{/systemd/system/.*\.service$}
          && $self->check_systemd_service_file($_)
    } @{$self->processable->installed->sorted_list};

    $self->services($self->get_systemd_service_names(\@service_files));

    my @timers = grep { m{^(?:usr/)?lib/systemd/system/[^\/]+\.timer$} }
      @{$self->processable->installed->sorted_list};
    $self->timers(\@timers);

    return;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    if (   $item->dirname eq 'etc/init.d/'
        && !$item->is_dir
        && (none { $item->basename eq $_} qw{README skeleton rc rcS})
        && $self->processable->name ne 'initscripts'
        && $item->link ne '/lib/init/upstart-job') {

        # sysv generator drops the .sh suffix
        my $service_name = $item->basename;
        $service_name =~ s/\.sh$//;

        $self->check_init_script($item, $self->services)
          unless $self->INIT_WHITELIST->recognizes($service_name);
    }

    if ($item->name =~ m{/systemd/system/.*\.socket$}) {

        my @values
          = $self->extract_service_file_values($item,'Socket','ListenStream');

        $self->hint('systemd-service-file-refers-to-var-run',
            $item, 'ListenStream', $_)
          for grep { m{^/var/run/} } @values;
    }

    $self->hint('missing-systemd-timer-for-cron-script', $item)
      if $item->dirname =~ m{^etc/cron\.[^\/]+/$} && !scalar @{$self->timers};

    return;
}

sub visit_control_files {
    my ($self, $item) = @_;

    return
      unless $item->is_maintainer_script;

    # look only at shell scripts
    return
      unless $item->hashbang =~ /^\S*sh\b/;

    my @lines = split(/\n/, $item->decoded_utf8);

    my $position = 1;
    for my $line (@lines) {

        next
          if $line =~ /^#/;

        # systemctl should not be called in maintainer scripts at all,
        # except for systemctl daemon-reload calls.
        $self->hint('maintainer-script-calls-systemctl', "$item:$position")
          if $line =~ /^(?:.+;)?\s*systemctl\b/
          && $line !~ /daemon-reload/;

    } continue {
        ++$position;
    }

    return;
}

# Verify that each init script includes /lib/lsb/init-functions,
# because that is where the systemd diversion happens.
sub check_init_script {
    my ($self, $file, $services) = @_;

    unless ($file->is_regular_file || $file->is_open_ok) {

        $self->hint('init-script-is-not-a-file', $file);
        return;
    }

    my $lsb_source_seen;
    my $is_rcs_script = 0;

    my @lines = split(/\n/, $file->decoded_utf8);

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

    $self->hint('init.d-script-does-not-source-init-functions', $file)
      unless $lsb_source_seen;

    my $servicename = $file->basename;
    $servicename =~ s/\.sh$//;

    if (!$services->{$servicename}) {
        # rcS scripts are particularly bad; always tag
        if ($is_rcs_script) {
            $self->hint('missing-systemd-service-for-init.d-rcS-script',
                $file->basename);
        } else {
            if (%{$services}) {
                $self->hint('omitted-systemd-service-for-init.d-script',
                    $file->basename);
            } else {
                $self->hint('missing-systemd-service-for-init.d-script',
                    $file->basename);
            }
        }
    }

    return;
}

sub get_systemd_service_names {
    my ($self,$files_ref) = @_;

    my %services;

    my $safe_add_service = sub {
        my ($name) = @_;
        if (exists $services{$name}) {
            # should add a tag here
            return;
        }
        $services{$name} = 1;
    };

    for my $file (@{$files_ref}) {
        my $name = $file->basename;
        $name =~ s/@?\.service$//;
        $safe_add_service->($name);

        my @aliases
          = $self->extract_service_file_values($file, 'Install', 'Alias');

        for my $alias (@aliases) {
            $self->hint('systemd-service-alias-without-extension', $file)
              if $alias !~ m/\.service$/;
            $alias =~ s/\.service$//;
            $safe_add_service->($alias);
        }
    }
    return \%services;
}

sub check_systemd_service_file {
    my ($self, $file) = @_;

    # ambivalent about /lib or /usr/lib
    $self->hint('systemd-service-in-odd-location', $file)
      if $file =~ m{^etc/systemd/system/};

    unless ($file->is_open_ok
        || ($file->is_symlink && $file->link eq '/dev/null')) {

        $self->hint('service-file-is-not-a-file', $file);
        return 0;
    }

    my @values = $self->extract_service_file_values($file, 'Unit', 'After');
    my @obsolete = grep { /^(?:syslog|dbus)\.target$/ } @values;

    $self->hint('systemd-service-file-refers-to-obsolete-target',$file, $_)
      for @obsolete;

    $self->hint('systemd-service-file-refers-to-obsolete-bindto', $file,)
      if $self->extract_service_file_values($file, 'Unit', 'BindTo');

    for my $key (
        qw(ExecStart ExecStartPre ExecStartPost ExecReload ExecStop ExecStopPost)
    ) {
        $self->hint('systemd-service-file-wraps-init-script', $file, $key)
          if any { m{^/etc/init\.d/} }
        $self->extract_service_file_values($file, 'Service', $key);
    }

    unless ($file->link eq '/dev/null') {

        my @wanted_by
          = $self->extract_service_file_values($file, 'Install', 'WantedBy');
        my $is_oneshot = any { $_ eq 'oneshot' }
        $self->extract_service_file_values($file, 'Service', 'Type');

        # We are a "standalone" service file if we have no .path or .timer
        # equivalent.
        my $is_standalone = 1;
        if ($file =~ m{^(usr/)?lib/systemd/system/([^/]*?)@?\.service$}) {

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
                $file, $target)
              unless (any { $target eq $_ } @WANTEDBY_WHITELIST)
              || $self->processable->name eq 'systemd';
        }

        $self->hint('systemd-service-file-missing-documentation-key', $file,)
          unless $self->extract_service_file_values($file, 'Unit',
            'Documentation');

        if (   !@wanted_by
            && !$is_oneshot
            && $is_standalone
            && $file =~ m{^(?:usr/)?lib/systemd/[^\/]+/[^\/]+\.service$}
            && $file !~ m{@\.service$}) {

            $self->hint('systemd-service-file-missing-install-key', $file)
              unless $self->extract_service_file_values($file, 'Install',
                'RequiredBy')
              || $self->extract_service_file_values($file, 'Install', 'Also');
        }

        my @pidfile
          = $self->extract_service_file_values($file,'Service','PIDFile');
        for my $x (@pidfile) {
            $self->hint('systemd-service-file-refers-to-var-run',
                $file, 'PIDFile', $x)
              if $x =~ m{^/var/run/};
        }

        my $seen_hardening
          = any { $self->extract_service_file_values($file, 'Service', $_) }
        @HARDENING_FLAGS;

        $self->hint('systemd-service-file-missing-hardening-features', $file)
          unless $seen_hardening
          || $is_oneshot
          || any { 'sleep.target' eq $_ } @wanted_by;

        if (
            $self->extract_service_file_values(
                $file, 'Unit', 'DefaultDependencies', 1
            )
        ) {
            my @before
              = $self->extract_service_file_values($file, 'Unit','Before');
            my @conflicts
              = $self->extract_service_file_values($file, 'Unit','Conflicts');

            $self->hint('systemd-service-file-shutdown-problems', $file,)
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
                $file, "$key=$value")
              if any { $_ eq $value }
            $self->extract_service_file_values($file, 'Service',$key);
        }

        for my $key (qw(StandardError StandardOutput)) {
            for my $value (qw(syslog syslog-console)) {

                $self->hint(
                    'systemd-service-file-uses-deprecated-syslog-facility',
                    $file, "$key=$value")
                  if any { $_ eq $value }
                $self->extract_service_file_values($file, 'Service',$key);
            }
        }
    }

    return 1;
}

sub service_file_lines {
    my ($file) = @_;

    my @output;

    return @output
      if $file->is_symlink and $file->link eq '/dev/null';

    my @lines = split(/\n/, $file->decoded_utf8);
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
          if $line eq $EMPTY;

        next
          if $line =~ /^[#;\n]/;

        push(@output, $line);
    }

    return @output;
}

# Extracts the values of a specific Key from a .service file
sub extract_service_file_values {
    my ($self, $file, $extract_section, $extract_key) = @_;

    my @unfiltered = service_file_lines($file);

    my @lines;
    for my $line (@unfiltered) {

        if ($line =~ /^\.include (.+)$/) {

            my $included = $file->parent_dir->resolve_path($1);

            if (defined $included) {
                push(@lines, service_file_lines($included));
                next;
            }
        }

        push(@lines, $line);
    }

    my @values;
    my $section;

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
            if ($value eq $EMPTY) {
                # Empty assignment resets the list
                @values = ();
            } else {
                push(@values, shellwords($value));
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
