# systemd -- lintian check script -*- perl -*-
#
# Copyright © 2013 Michael Stapelberg
# Copyright © 2016-2020 Chris Lamb <lamby@debian.org>
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
use List::SomeUtils qw(any first_index);
use Text::ParseWords qw(shellwords);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

has timers => (is => 'rwp', default => sub{ [] });

sub setup_installed_files {
    my ($self) = @_;

    my @timers = grep { m{^lib/systemd/system/[^\/]+\.timer$} }
      @{$self->processable->installed->sorted_list};
    $self->_set_timers(\@timers);

    return;
}

sub visit_installed_files {
    my ($self, $file) = @_;

    $self->hint('missing-systemd-timer-for-cron-script', $file)
      if $file->dirname =~ m{^etc/cron\.[^\/]+/$} && !scalar @{$self->timers};

    return;
}

sub installable {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $processable = $self->processable;

    my @init_scripts = $self->get_init_scripts;
    my @service_files = $self->get_systemd_service_files;

    # A hash of names reference which are provided by the service files.
    # This includes Alias= directives, so after parsing
    # NetworkManager.service, it will contain NetworkManager and
    # network-manager.
    my $services = $self->get_systemd_service_names(\@service_files);

    for my $script (@init_scripts) {
        $self->check_init_script($script, $services);
    }

    $self->check_maintainer_scripts();
    $self->check_systemd_socket_files();

    return;
}

sub get_init_service_name {
    my ($file) = @_;
    my $basename = $file->basename;
    # sysv generator drops the .sh suffix
    $basename =~ s/\.sh$//;
    return $basename;
}

sub get_init_scripts {
    my ($self) = @_;

    my $processable = $self->processable;

    # Init scripts that do not need a service file
    my $INIT_WHITELIST = $self->profile->load_data('systemd/init-whitelist');

    my @scripts;
    if ($processable->name ne 'initscripts'
        and my $initd_path
        = $processable->installed->resolve_path('etc/init.d/')){
        for my $init_script ($initd_path->children) {
            # sysv generator drops the .sh suffix
            my $basename = get_init_service_name($init_script);
            next if $INIT_WHITELIST->recognizes($basename);
            next
              if $init_script->is_symlink
              && $init_script->link eq '/lib/init/upstart-job';

            push(@scripts, $init_script);
        }
    }
    return @scripts;
}

# Verify that each init script includes /lib/lsb/init-functions,
# because that is where the systemd diversion happens.
sub check_init_script {
    my ($self, $file, $services) = @_;

    my $processable = $self->processable;
    my $basename = $file->basename;
    my $servicename = get_init_service_name($file);
    my $lsb_source_seen;
    my $is_rcs_script = 0;

    if (!$file->is_regular_file) {
        unless ($file->is_open_ok) {
            $self->hint('init-script-is-not-a-file', $file);
            return;
        }
    }

    open(my $fh, '<', $file->unpacked_path)
      or die encode_utf8('Cannot open ' . $file->unpacked_path);

    while (my $line = <$fh>) {

        # trim left
        $line =~ s/^\s+//;

        $lsb_source_seen = 1
          if $. == 1
          && $line
          =~ m{\A [#]! \s* (?:/usr/bin/env)? \s* /lib/init/init-d-script}xsm;

        $is_rcs_script = 1
          if $line =~ m{#.*Default-Start:.*S};

        next
          if $line =~ /^#/;

        $lsb_source_seen = 1
          if $line
          =~ m{(?:\.|source)\s+/lib/(?:lsb/init-functions|init/init-d-script)};
    }
    close($fh);

    $self->hint('init.d-script-does-not-source-init-functions', $file)
      unless $lsb_source_seen;

    if (!$services->{$servicename}) {
        # rcS scripts are particularly bad; always tag
        if ($is_rcs_script) {
            $self->hint('missing-systemd-service-for-init.d-rcS-script',
                $basename);
        } else {
            if (%{$services}) {
                $self->hint('omitted-systemd-service-for-init.d-script',
                    $basename);
            } else {
                $self->hint('missing-systemd-service-for-init.d-script',
                    $basename);
            }
        }
    }

    return;
}

sub get_systemd_service_files {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $processable = $self->processable;
    my @res;
    my @potential
      = grep { m{/systemd/system/.*\.service$} }
      @{$processable->installed->sorted_list};

    for my $file (@potential) {
        push(@res, $file) if $self->check_systemd_service_file($file);
    }
    return @res;
}

sub get_systemd_service_names {
    my ($self,$files_ref) = @_;

    my $processable = $self->processable;
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

    my $pkg = $self->processable->name;
    my $processable = $self->processable;

    # Known security flags
    my $HARDENING_FLAGS = $self->profile->load_data('systemd/hardening-flags');

    # Usual WantedBy= targets
    my $WANTEDBY_WHITELIST
      = $self->profile->load_data('systemd/wantedby-whitelist');

    $self->hint('systemd-service-file-outside-lib', $file)
      if ($file =~ m{^etc/systemd/system/});
    $self->hint('systemd-service-file-outside-lib', $file)
      if ($file =~ m{^usr/lib/systemd/system/});

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

    if (not $file->is_symlink or $file->link ne '/dev/null') {

        my @wanted_by
          = $self->extract_service_file_values($file, 'Install', 'WantedBy');
        my $is_oneshot = any { $_ eq 'oneshot' }
        $self->extract_service_file_values($file, 'Service', 'Type');

        # We are a "standalone" service file if we have no .path or .timer
        # equivalent.
        my $is_standalone = 1;
        if ($file =~ m{^lib/systemd/system/([^/]*?)@?\.service$}) {
            my $service = $1;
            for my $x (qw(path timer)) {
                $is_standalone = 0
                  if $processable->installed->resolve_path(
                    "lib/systemd/system/${service}.${x}");
            }
        }

        foreach my $target (@wanted_by) {
            $self->hint(
                'systemd-service-file-refers-to-unusual-wantedby-target',
                $file, $target)
              unless any { $target eq $_ } $WANTEDBY_WHITELIST->all
              or $pkg eq 'systemd';
        }
        $self->hint('systemd-service-file-missing-documentation-key', $file,)
          unless $self->extract_service_file_values($file, 'Unit',
            'Documentation');

        if (   !@wanted_by
            && !$is_oneshot
            && $is_standalone
            && $file =~ m{^lib/systemd/[^\/]+/[^\/]+\.service$}
            && $file !~ m{@\.service$}) {

            $self->hint('systemd-service-file-missing-install-key', $file)
              unless $self->extract_service_file_values($file, 'Install',
                'RequiredBy')
              || $self->extract_service_file_values($file, 'Install', 'Also');
        }

        my @pidfile
          = $self->extract_service_file_values($file,'Service','PIDFile');
        foreach my $x (@pidfile) {
            $self->hint('systemd-service-file-refers-to-var-run',
                $file, 'PIDFile', $x)
              if $x =~ m{^/var/run/};
        }
        my $seen_hardening;
        foreach my $x ($HARDENING_FLAGS->all) {
            next
              unless $self->extract_service_file_values($file, 'Service', $x);
            $seen_hardening = 1;
            last;
        }
        $self->hint('systemd-service-file-missing-hardening-features', $file)
          unless $seen_hardening
          or $is_oneshot
          or any { 'sleep.target' eq $_ } @wanted_by;

        if (
            $self->extract_service_file_values(
                $file, 'Unit', 'DefaultDependencies', 1
            )
        ) {

            my $seen_conflicts_shutdown = 0;
            my @conflicts
              = $self->extract_service_file_values($file, 'Unit','Conflicts');
            foreach my $x (@conflicts) {
                next unless $x eq 'shutdown.target';
                $seen_conflicts_shutdown = 1;
                last;
            }
            if ($seen_conflicts_shutdown) {
                my $seen_before_shutdown = 0;
                my @before
                  = $self->extract_service_file_values($file, 'Unit','Before');
                foreach my $x (@before) {
                    next unless $x eq 'shutdown.target';
                    $seen_before_shutdown = 1;
                    last;
                }
                $self->hint('systemd-service-file-shutdown-problems', $file,)
                  unless $seen_before_shutdown;
            }
        }

        my %bad_users = (
            'User' => 'nobody',
            'Group' => 'nogroup',
        );

        for my $key (keys %bad_users) {

            my $value = $bad_users{$key};

            if (
                any { $_ eq $value }
                $self->extract_service_file_values($file, 'Service',$key)
            ) {
                $self->hint('systemd-service-file-uses-nobody-or-nogroup',
                    $file, "$key=$value");
            }
        }

        foreach my $key (qw(StandardError StandardOutput)) {
            foreach my $value (qw(syslog syslog-console)) {
                if (
                    any { $_ eq $value }
                    $self->extract_service_file_values($file, 'Service',$key)
                ) {
                    $self->hint(
                        'systemd-service-file-uses-deprecated-syslog-facility',
                        $file, "$key=$value"
                    );
                }
            }
        }
    }

    return 1;
}

sub service_file_lines {
    my ($path) = @_;

    my (@lines, $continuation);
    return ()
      if $path->is_symlink and $path->link eq '/dev/null';

    open(my $fh, '<', $path->unpacked_path)
      or die encode_utf8('Cannot open ' . $path->unpacked_path);

    while (my $line = <$fh>) {
        chomp $line;

        if (defined $continuation) {
            $line = $continuation . $line;
            $continuation = undef;
        }

        if ($line =~ /\\$/) {
            $continuation = $line;
            $continuation =~ s/\\$/ /;
            next;
        }

        # trim right
        $line =~ s/\s+$//;

        next
          if $line eq $EMPTY;

        next
          if $line =~ /^[#;\n]/;

        push(@lines, $line);
    }
    close($fh);

    return @lines;
}

# Extracts the values of a specific Key from a .service file
sub extract_service_file_values {
    my ($self, $file, $extract_section, $extract_key) = @_;

    my (@values, $section);

    my @unfiltered = service_file_lines($file);

    my @lines;
    for my $line (@unfiltered) {

        if ($line =~ /^\.include (.+)$/) {
            my $path = $file->parent_dir->resolve_path($1);
            if (defined $path && $path->is_open_ok) {
                push(@lines, service_file_lines($path));
                next;
            }
        }

        push(@lines, $line);
    }

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

sub check_maintainer_scripts {
    my ($self) = @_;

    # get maintainer scripts
    my @control
      = grep { $_->is_control } @{$self->processable->control->sorted_list};

    for my $file (@control) {

        # skip anything but shell scripts
        my $hashbang = $file->hashbang;
        next
          unless $hashbang =~ m/^\S*sh\b/;

        # Don't follow unsafe links
        next
          unless $file->is_open_ok;

        open(my $sfd, '<', $file->unpacked_path)
          or die encode_utf8('Cannot open ' . $file->unpacked_path);

        while (my $line = <$sfd>) {
            # skip comments
            next
              if $line =~ /^#/;

            # systemctl should not be called in maintainer scripts at all,
            # except for systemctl daemon-reload calls.
            $self->hint('maintainer-script-calls-systemctl', "$file:$.")
              if $line =~ /^(?:.+;)?\s*systemctl\b/
              && $line !~ /daemon-reload/;
        }
        close($sfd);
    }

    return;
}

sub check_systemd_socket_files {
    my ($self) = @_;

    my @files = @{$self->processable->installed->sorted_list};

    foreach my $file (grep { m{/systemd/system/.*\.socket$} } @files) {
        my @xs
          = $self->extract_service_file_values($file,'Socket','ListenStream');
        foreach my $x (@xs) {
            $self->hint('systemd-service-file-refers-to-var-run',
                $file, 'ListenStream', $x)
              if $x =~ m{^/var/run/};
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
