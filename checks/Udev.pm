# udev -- lintian check script -*- perl -*-

# Copyright © 2016 Petter Reinholdtsen
# Copyright © 2018 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Udev;

use v5.20;
use warnings;
use utf8;
use autodie qw(open);

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

# Check /lib/udev/rules.d/, detect use of MODE="0666" and use of
# GROUP="plugdev" without TAG+="uaccess".

sub installable {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $type = $self->processable->type;
    my $processable = $self->processable;
    my $group = $self->group;

    my $rules_dir = $processable->installed->resolve_path('lib/udev/rules.d/');
    return unless $rules_dir;
    foreach my $file ($rules_dir->children) {
        if (!$file->is_open_ok) {
            $self->hint('udev-rule-unreadable', $file);
            next;
        }
        $self->check_udev_rules($file);
    }
    return;
}

sub check_rule {
    my ($self, $file, $linenum, $in_goto, $rule) = @_;

    # for USB, if everyone or the plugdev group members are
    # allowed access, the uaccess tag should be used too.
    if (
        $rule =~ m/SUBSYSTEM=="usb"/
        && (   $rule =~ m/GROUP="plugdev"/
            || $rule =~ m/MODE="0666"/)
        && $rule !~ m/ENV\{COLOR_MEASUREMENT_DEVICE\}/
        && $rule !~ m/ENV\{DDC_DEVICE\}/
        && $rule !~ m/ENV\{ID_CDROM\}/
        && $rule !~ m/ENV\{ID_FFADO\}/
        && $rule !~ m/ENV\{ID_GPHOTO2\}/
        && $rule !~ m/ENV\{ID_HPLIP\}/
        && $rule !~ m/ENV\{ID_INPUT_JOYSTICK\}/
        && $rule !~ m/ENV\{ID_MAKER_TOOL\}/
        && $rule !~ m/ENV\{ID_MEDIA_PLAYER\}/
        && $rule !~ m/ENV\{ID_PDA\}/
        && $rule !~ m/ENV\{ID_REMOTE_CONTROL\}/
        && $rule !~ m/ENV\{ID_SECURITY_TOKEN\}/
        && $rule !~ m/ENV\{ID_SMARTCARD_READER\}/
        && $rule !~ m/ENV\{ID_SOFTWARE_RADIO\}/
        && $rule !~ m/TAG\+="uaccess"/
    ) {
        $self->hint((
            'udev-rule-missing-uaccess',
            "$file:$linenum",
            'user accessible device missing TAG+="uaccess"'
        ));
    }

    # Matching rules mentioning vendor/product should also specify
    # subsystem, as vendor/product is subsystem specific.
    if (   $rule =~ m/ATTR\{idVendor\}=="[0-9a-fA-F]+"/
        && $rule =~ m/ATTR\{idProduct\}=="[0-9a-fA-F]*"/
        && !$in_goto
        && $rule !~ m/SUBSYSTEM=="[^"]+"/) {
        $self->hint((
            'udev-rule-missing-subsystem',
            "$file:$linenum",
            'vendor/product matching missing SUBSYSTEM specifier'
        ));
    }

    return 0;
}

sub check_udev_rules {
    my ($self, $file) = @_;

    my $contents = $file->decoded_utf8;
    my @lines = split(/\n/, $contents);

    my $continued = $EMPTY;
    my $in_goto = $EMPTY;
    my $result = 0;

    my $linenum = 1;
    while (defined(my $line = shift @lines)) {

        if (length $continued) {
            $line = $continued . $line;
            $continued = $EMPTY;
        }

        if ($line =~ /^(.*)\\$/) {
            $continued = $1;
            next;
        }

        # Skip comments
        next
          if $line =~ /^#.*/;

        $in_goto = $EMPTY
          if $line =~ /LABEL="[^"]+"/;

        $in_goto = $line
          if $line =~ /SUBSYSTEM!="[^"]+"/
          && $line =~ /GOTO="[^"]+"/;

        $result |= $self->check_rule($file, $linenum, $in_goto, $line);

    } continue {
        $linenum++;
    }

    return $result;
}

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      unless $file->name =~ m{^etc/udev/};

    # /etc/udev/rules.d
    $self->hint('udev-rule-in-etc', $file->name)
      if $file->name =~ m{^etc/udev/rules\.d/\S};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
