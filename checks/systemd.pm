# systemd -- lintian check script -*- perl -*-
#
# Copyright © 2013 Michael Stapelberg
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

package Lintian::systemd;

use strict;
use warnings;
use autodie;

use File::Basename;
use List::MoreUtils qw(any);
use Text::ParseWords qw(shellwords);

use Lintian::Tags qw(tag);
use Lintian::Util qw(fail lstrip rstrip);

sub run {
    my (undef, undef, $info) = @_;

    # Figure out whether the maintainer of this package did any effort to
    # make the package work with systemd. If not, we will not warn in case
    # of an init script that has no systemd equivalent, for example.
    my $ships_systemd_file = any { m,/systemd/, } $info->sorted_index;

    # An array of names which are provided by the service files.
    # This includes Alias= directives, so after parsing
    # NetworkManager.service, it will contain NetworkManager and
    # network-manager.
    my @systemd_targets;

    for my $file ($info->sorted_index) {
        if ($file =~ m,^etc/tmpfiles\.d/.*\.conf$,) {
            tag 'systemd-tmpfiles.d-outside-usr-lib', $file;
        }
        if ($file =~ m,^etc/systemd/system/.*\.service$,) {
            tag 'systemd-service-file-outside-lib', $file;
        }
        if ($file =~ m,/systemd/system/.*\.service$,) {
            check_systemd_service_file($info, $file);
            for my $name (extract_service_file_names($info, $file)) {
                push @systemd_targets, $name;
            }
        }
    }

    my @init_scripts = grep { m,^etc/init\.d/.+, } $info->sorted_index;

    # Verify that each init script includes /lib/lsb/init-functions,
    # because that is where the systemd diversion happens.
    for my $init_script (@init_scripts) {
        check_init_script($info, $init_script);
    }

    @init_scripts = map { basename($_) } @init_scripts;

    if ($ships_systemd_file) {
        for my $init_script (@init_scripts) {
            tag 'systemd-no-service-for-init-script', $init_script
              unless any { m/\Q$init_script\E\.service/ } @systemd_targets;
        }
    }

    check_maintainer_scripts($info);
    return;
}

sub check_init_script {
    my ($info, $file) = @_;
    my $basename = $file->basename;
    my $lsb_source_seen;

    # Couple of special cases we don't care about...
    return
         if $basename eq 'README'
      or $basename eq 'skeleton'
      or $basename eq 'rc'
      or $basename eq 'rcS';

    if ($file->is_symlink) {
        # We cannot test upstart-jobs
        return if $file->link eq '/lib/init/upstart-job';
    }

    if (!$file->is_regular_file) {
        unless ($file->is_open_ok) {
            tag 'init-script-is-not-a-file', $file;
            return;
        }

    }

    my $fh = $file->open;
    while (<$fh>) {
        lstrip;
        if ($. == 1 and m{\A [#]! \s*/lib/init/init-d-script}xsm) {
            $lsb_source_seen = 1;
            last;
        }
        next if /^#/;
        if (m,(?:\.|source)\s+/lib/(?:lsb/init-functions|init/init-d-script),){
            $lsb_source_seen = 1;
            last;
        }
    }
    close($fh);

    if (!$lsb_source_seen) {
        tag 'init.d-script-does-not-source-init-functions', $file;
    }
    return;
}

sub check_systemd_service_file {
    my ($info, $file) = @_;

    my @values = extract_service_file_values($info, $file, 'Unit', 'After');
    my @obsolete = grep { /^(?:syslog|dbus)\.target$/ } @values;
    tag 'systemd-service-file-refers-to-obsolete-target', $file, $_
      for @obsolete;
    return;
}

sub service_file_lines {
    my ($path) = @_;
    my (@lines, $continuation);
    return if $path->is_symlink and $path->link eq '/dev/null';

    my $fh = $path->open;
    while (<$fh>) {
        chomp;

        if (defined($continuation)) {
            $_ = $continuation . $_;
            $continuation = undef;
        }

        if (/\\$/) {
            $continuation = $_;
            $continuation =~ s/\\$/ /;
            next;
        }

        rstrip;

        next if $_ eq '';

        next if /^[#;\n]/;

        push @lines, $_;
    }
    close($fh);

    return @lines;
}

# Extracts the values of a specific Key from a .service file
sub extract_service_file_values {
    my ($info, $file, $extract_section, $extract_key) = @_;

    my (@values, $section);

    unless ($file->is_open_ok
        || ($file->is_symlink && $file->link eq '/dev/null')) {
        tag 'service-file-is-not-a-file', $file;
        return;
    }
    my @lines = service_file_lines($file);
    if (any { /^\.include / } @lines) {
        my $parent_dir = $file->parent_dir;
        @lines = map {
            if (/^\.include (.+)$/) {
                my $path = $parent_dir->resolve_path($1);
                if (defined($path)
                    && $path->is_open_ok) {
                    service_file_lines($path);
                } else {
                    # doesn't exist, exists but not a file or "out-of-bounds"
                    $_;
                }
            } else {
                $_;
            }
        } @lines;
    }
    for (@lines) {
        # section header
        if (/^\[([^\]]+)\]$/) {
            $section = $1;
            next;
        }

        if (!defined($section)) {
            # Assignment outside of section. Ignoring.
            next;
        }

        my ($key, $value) = ($_ =~ m,^(.*)\s*=\s*(.*)$,);
        if (   $section eq $extract_section
            && $key eq $extract_key) {
            if ($value eq '') {
                # Empty assignment resets the list
                @values = ();
            } else {
                push(@values, shellwords($value));
            }
        }
    }

    return @values;
}

sub extract_service_file_names {
    my ($info, $file) = @_;

    my @aliases= extract_service_file_values($info, $file, 'Install', 'Alias');
    return (basename($file), @aliases);
}

sub check_maintainer_scripts {
    my ($info) = @_;

    open(my $fd, '<', $info->lab_data_path('control-scripts'));

    while (<$fd>) {
        m/^(\S*) (.*)$/ or fail("bad line in control-scripts file: $_");
        my $interpreter = $1;
        my $file = $2;
        my $path = $info->control_index_resolved_path($file);

        # Don't follow unsafe links
        next if not $path or not $path->is_open_ok;
        # Don't try to parse the file if it does not appear to be a
        # shell script
        next if $interpreter !~ m/sh\b/;

        my $sfd = $path->open;
        while (<$sfd>) {
            # skip comments
            next if substr($_, 0, $-[0]) =~ /#/;

            # systemctl should not be called in maintainer scripts at all,
            # except for systemctl --daemon-reload calls.
            if (m/^(?:.+;)?\s*systemctl\b/ && !/daemon-reload/) {
                tag 'maintainer-script-calls-systemctl', "$file:$.";
            }
        }
        close($sfd);
    }

    close($fd);
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
