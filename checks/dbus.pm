# dbus -- lintian check script, vaguely based on apache2 -*- perl -*-
#
# Copyright © 2012 Arno Töll
# Copyright © 2014 Collabora Ltd.
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

package Lintian::dbus;

use strict;
use warnings;
use autodie;

use Lintian::Tags qw(tag);
use Lintian::Util qw(slurp_entire_file);

sub run {
    my ($pkg, $type, $info) = @_;

    my @files;
    foreach my $dirname (qw(session system)) {
        if (my $dir = $info->index_resolved_path("etc/dbus-1/${dirname}.d")) {
            push @files, $dir->children;
        }
    }

    foreach my $file (@files) {
        next unless $file->is_open_ok;
        _check_policy($file);
    }

    if (my $dir = $info->index_resolved_path('usr/share/dbus-1/services')) {
        foreach my $file ($dir->children) {
            next unless $file->is_open_ok;
            _check_service($file, session => 1);
        }
    }

    if (my $dir
        = $info->index_resolved_path('usr/share/dbus-1/system-services')) {
        foreach my $file ($dir->children) {
            next unless $file->is_open_ok;
            _check_service($file);
        }
    }

    return;
}

sub _check_policy {
    my ($file) = @_;

    my $xml = $file->file_contents;

    # Parsing XML via regexes is evil, but good enough here...
    # note that we are parsing the entire file as one big string,
    # so that we catch <policy\nat_console="true"\n> or whatever.

    if ($xml =~ m{<policy[^>]+at_console=(["'])true\1.*?</policy>}s) {
        tag('dbus-policy-at-console', $file);
    }

    my @rules;
    while ($xml =~ m{(<(?:allow|deny)[^>]+send_\w+=[^>]+>)}sg) {
        push(@rules, $1);
    }
    foreach my $rule (@rules) {
        if ($rule !~ m{send_destination=}) {
            # normalize whitespace a bit
            $rule =~ s{\s+}{ }g;
            tag('dbus-policy-without-send-destination', $file, $rule);
        }
    }

    return;
}

sub _check_service {
    my ($file, %kwargs) = @_;

    my $basename = $file->basename;
    my $text = $file->file_contents;

    while ($text =~ m{^Name=(.*)$}gm) {
        my $name = $1;
        if ($basename ne "${name}.service") {
            if ($kwargs{session}) {
                tag('dbus-session-service-wrong-name',
                    "${name}.service", $file);
            } else {
                tag('dbus-system-service-wrong-name',"${name}.service", $file);
            }
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
