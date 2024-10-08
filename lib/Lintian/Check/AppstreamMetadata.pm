# appstream-metadata -- lintian check script -*- perl -*-

# Copyright (C) 2016,2024 Petter Reinholdtsen
# Copyright (C) 2017-2018 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::AppstreamMetadata;

# For .desktop files, the lintian check would be really easy: Check if
# .desktop file is there, check if matching file exists in
# /usr/share/metainfo, if not throw a warning. Maybe while we're at it
# also check for legacy locations (stuff in /usr/share/appdata) and
# legacy data (metainfo files starting with `<application>`).
#
# For modaliases, maybe udev rules could give some hints.
# Check modalias values to ensure hex numbers are using capital A-F.
#
# For metadata XML files, validate the content using "appstreamcli
# validate".

use v5.20;
use warnings;
use utf8;
use autodie qw(open);

use File::Basename qw(basename);
use Syntax::Keyword::Try;
use XML::LibXML;

use Capture::Tiny qw(capture_merged);
use Moo;
use YAML::XS;
use namespace::clean;

with 'Lintian::Check';

sub installable {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $type = $self->processable->type;
    my $processable = $self->processable;
    my $group = $self->group;

    my (%desktopfiles, %metainfo, @udevrules);
    my $found_modalias = 0;
    my $modaliases = [];
    if (
        defined(
            my $dir
              = $processable->installed->resolve_path(
                'usr/share/applications/')
        )
    ) {
        for my $item ($dir->descendants) {
            $desktopfiles{$item} = 1 if ($item->is_file);
        }
    }
    if (
        defined(
            my $dir
              = $processable->installed->resolve_path('usr/share/metainfo/')
        )
    ) {
        for my $item ($dir->children) {
            if ($item->is_file) {
                $metainfo{$item} = 1;
                $found_modalias|= $self->check_modalias($item, $modaliases);
            }
        }
        my $basedir = $processable->installed->basedir;
        my ($output, $status) = capture_merged {
            system('appstreamcli', 'validate-tree', '--format=yaml',
                '--no-net', $basedir);
        };
        if ($output =~ m/Passed: no/) {
            my @yaml = YAML::XS::Load($output);
            die
              unless @yaml;
            $self->hint('appstream-metadata-validation-failed',
                q{Problems reported by "appstreamcli validate-tree".});
        }
    }
    if (
        defined(
            my $dir
              = $processable->installed->resolve_path('usr/share/appdata/')
        )
    ) {
        for my $item ($dir->descendants) {
            if ($item->is_file) {

                $self->pointed_hint('appstream-metadata-in-legacy-location',
                    $item->pointer);
                $found_modalias|= $self->check_modalias($item, $modaliases);
            }
        }
    }
    foreach my $lib_dir (qw(usr/lib lib)) {
        if (
            defined(
                my $dir = $processable->installed->resolve_path(
                    "$lib_dir/udev/rules.d/")
            )
        ) {
            for my $item ($dir->descendants) {
                push(@udevrules, $item) if ($item->is_file);
            }
        }
    }

    for my $udevrule (@udevrules) {
        if ($self->check_udev_rules($udevrule, $modaliases)
            && !$found_modalias) {

            $self->hint('appstream-metadata-missing-modalias-provide',
                $udevrule);
        }
    }
    return;
}

sub check_modalias {
    my ($self, $item, $modaliases) = @_;

    if (!$item->is_open_ok) {
        # FIXME report this as an error
        return 0;
    }

    my $parser = XML::LibXML->new;
    $parser->set_option('no_network', 1);

    my $doc;
    try {
        $doc = $parser->parse_file($item->unpacked_path);

    } catch {

        $self->pointed_hint('appstream-metadata-invalid',$item->pointer);

        return 0;
    }

    return 0
      unless $doc;

    if ($doc->findnodes('/application')) {

        $self->pointed_hint('appstream-metadata-legacy-format',$item->pointer);
        return 0;
    }

    my @provides = $doc->findnodes('/component/provides');
    return 0
      unless @provides;

    # take first one
    my $first = $provides[0];
    return 0
      unless $first;

    my @nodes = $first->getChildrenByTagName('modalias');
    return 0
      unless @nodes;

    for my $node (@nodes) {

        my $alias = $node->firstChild->data;
        next
          unless $alias;

        push(@{$modaliases}, $alias);

        $self->pointed_hint('appstream-metadata-malformed-modalias-provide',
            $item->pointer,
            "include non-valid hex digit in USB matching rule '$alias'")
          if $alias =~ /^usb:v[0-9a-f]{4}p[0-9a-f]{4}d/i
          && $alias !~ /^usb:v[0-9A-F]{4}p[0-9A-F]{4}d/;
    }

    return 1;
}

sub provides_user_device {
    my ($self, $item, $position, $rule, $data) = @_;

    my $retval = 0;

    if (   $rule =~ /plugdev/
        || $rule =~ /uaccess/
        || $rule =~ /MODE=\"0666\"/) {

        $retval = 1;
    }

    if ($rule =~ m/SUBSYSTEM=="usb"/) {
        my ($vmatch, $pmatch);
        if ($rule =~ m/ATTR\{idVendor\}=="([0-9a-fA-F]{4})"/) {
            $vmatch = 'v' . uc($1);
        }

        if ($rule =~ m/ATTR\{idProduct\}=="([0-9a-fA-F]{4})"/) {
            $pmatch = 'p' . uc($1);
        }

        if (defined $vmatch && defined $pmatch) {
            my $match = "usb:${vmatch}${pmatch}d";
            my $foundmatch;
            for my $aliasmatch (@{$data}) {
                if (0 == index($aliasmatch, $match)) {
                    $foundmatch = 1;
                }
            }

            $self->pointed_hint(
                'appstream-metadata-missing-modalias-provide',
                $item->pointer($position),
                "match rule $match*"
            ) unless $foundmatch;
        }
    }

    return $retval;
}

sub check_udev_rules {
    my ($self, $item, $data) = @_;

    open(my $fd, '<', $item->unpacked_path);

    my $cont;
    my $retval = 0;

    my $position = 0;
    while (my $line = <$fd>) {

        chomp $line;

        if (defined $cont) {
            $line = $cont . $line;
            $cont = undef;
        }

        if ($line =~ /^(.*)\\$/) {
            $cont = $1;
            next;
        }

        # skip comments
        next
          if $line =~ /^#.*/;

        $retval |= $self->provides_user_device($item, $position, $line, $data);

    } continue {
        ++$position;
    }

    close $fd;

    return $retval;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
