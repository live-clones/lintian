# desktop/dbus -- lintian check script, vaguely based on apache2 -*- perl -*-
#
# Copyright © 2012 Arno Töll
# Copyright © 2014 Collabora Ltd.
# Copyright © 2021 Felix Lechner
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

package Lintian::Check::Desktop::Dbus;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::UtilsBy qw(uniq_by);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

sub installable {
    my ($self) = @_;

    my $index = $self->processable->installed;

    my @files;
    for my $prefix (qw(etc/dbus-1 usr/share/dbus-1)) {
        for my $suffix (qw(session system)) {

            my $folder = $index->resolve_path("${prefix}/${suffix}.d");
            next
              unless defined $folder;

            push(@files, $folder->children);
        }
    }

    my @unique = uniq_by { $_->name } @files;

    $self->check_policy($_)for @unique;

    if (my $folder= $index->resolve_path('usr/share/dbus-1/services')) {

        $self->check_service($_, session => 1)for $folder->children;
    }

    if (my $folder= $index->resolve_path('usr/share/dbus-1/system-services')) {
        $self->check_service($_)for $folder->children;
    }

    return;
}

my $PROPERTIES = 'org.freedesktop.DBus.Properties';

sub check_policy {
    my ($self, $file) = @_;

    my $xml = $file->decoded_utf8;
    return
      unless length $xml;

    # Parsing XML via regexes is evil, but good enough here...
    # note that we are parsing the entire file as one big string,
    # so that we catch <policy\nat_console="true"\n> or whatever.

    my @rules;
    # a small rubbish state machine: we want to match a <policy> containing
    # any <allow> or <deny> rule that is about sending
    my $policy = $EMPTY;
    while ($xml =~ m{(<policy[^>]*>)|(</policy\s*>)|(<(?:allow|deny)[^>]*>)}sg)
    {
        if (defined $1) {
            $policy = $1;
        } elsif (defined $2) {
            $policy = $EMPTY;
        } else {
            push(@rules, $policy.$3);
        }
    }

    my $position = 1;
    for my $rule (@rules) {
        # normalize whitespace a bit so we can report it sensibly:
        # typically it will now look like
        # <policy context="default"><allow send_destination="com.example.Foo"/>
        $rule =~ s{\s+}{ }g;

        if ($rule =~ m{send_} && $rule !~ m{send_destination=}) {
            # It is about sending but does not specify a send-destination.
            # This could be bad.

            if ($rule =~ m{[^>]*user=['"]root['"].*<allow}) {
                # skip it: it's probably the "agent" pattern (as seen in
                # e.g. BlueZ), and cannot normally be a security flaw
                # because root can do anything anyway

            } else {
                $self->hint('dbus-policy-without-send-destination',
                    $file, "(rule $position)", $rule);

                if (   $rule =~ m{send_interface=}
                    && $rule !~ m{send_interface=['"]\Q${PROPERTIES}\E['"]}) {
                    # That's undesirable, because it opens up communication
                    # with arbitrary services and can undo DoS mitigation
                    # efforts; but at least it's specific to an interface
                    # other than o.fd.DBus.Properties, so all that should
                    # happen is that the service sends back an error message.
                    #
                    # Properties doesn't count as an effective limitation,
                    # because it's a sort of meta-interface.

                } elsif ($rule =~ m{<allow}) {
                    # Looks like CVE-2014-8148 or similar. This is really bad;
                    # emit an additional tag.
                    $self->hint('dbus-policy-excessively-broad',
                        $file, "(rule $position)", $rule);
                }
            }
        }

        $self->hint('dbus-policy-at-console', $file, "(rule $position)", $rule)
          if $rule =~ m{at_console=['"]true};

    } continue {
        ++$position;
    }

    return;
}

sub check_service {
    my ($self, $file, %kwargs) = @_;

    my $text = $file->decoded_utf8;
    return
      unless length $text;

    while ($text =~ m{^Name=(.*)$}gm) {

        my $name = $1;

        next
          if $file->basename eq "${name}.service";

        if ($kwargs{session}) {
            $self->hint('dbus-session-service-wrong-name',
                "${name}.service", $file);
        } else {
            $self->hint(
                ('dbus-system-service-wrong-name',"${name}.service", $file));
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
