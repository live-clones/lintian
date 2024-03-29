# debian/readme -- lintian check script -*- perl -*-

# Copyright (C) 1998 Richard Braakman
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

package Lintian::Check::Debian::Readme;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Spelling qw(check_spelling);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $VERTICAL_BAR => q{|};

sub spelling_tag_emitter {
    my ($self, $tag_name, $item, @orig_args) = @_;

    my $pointer = $item->pointer($.);

    return sub {
        return $self->pointed_hint($tag_name, $pointer, @orig_args, @_);
    };
}

sub open_readme {
    my ($pkg_name, $processable) = @_;

    my $doc_dir
      = $processable->installed->resolve_path("usr/share/doc/${pkg_name}/");

    if (defined $doc_dir) {

        for my $name (
            qw(README.Debian.gz README.Debian README.debian.gz README.debian)){

            my $path = $doc_dir->child($name);

            next
              unless $path && $path->is_open_ok;

            if ($name =~ m/\.gz$/) {
                open(my $fd, '<:gzip', $path->unpacked_path)
                  or die encode_utf8('Cannot open ' . $path->unpacked_path);

                return $fd;
            }

            open(my $fd, '<', $path->unpacked_path)
              or die encode_utf8('Cannot open ' . $path->unpacked_path);

            return $fd;
        }
    }

    return undef;
}

sub installable {
    my ($self) = @_;

    my $pkg_name = $self->processable->name;
    my $group = $self->group;

    my $doc_dir
      = $self->processable->installed->resolve_path(
        "usr/share/doc/${pkg_name}/");

    return
      unless defined $doc_dir;

    my $item;
    my $fd;

    for my $name (
        qw(README.Debian.gz README.Debian README.debian.gz README.debian)){

        $item = $doc_dir->child($name);

        next
          unless $item && $item->is_open_ok;

        if ($name =~ m/\.gz$/) {
            open($fd, '<:gzip', $item->unpacked_path)
              or die encode_utf8('Cannot open ' . $item->unpacked_path);

            last;
        }

        open($fd, '<', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        last;
    }

    return
      unless defined $item
      && defined $fd;

    my $readme = $EMPTY;

    my $position = 1;
    while (my $line = <$fd>) {

        my $pointer = $item->pointer($position);

        $self->pointed_hint('readme-debian-mentions-usr-doc', $pointer)
          if $line =~ m{ /usr/doc \b }x;

        $readme .= $line;

    } continue {
        ++$position;
    }

    close $fd;

    my @template =(
        'Comments regarding the Package',
        'So far nothing to say',
        '<possible notes regarding this package - if none, delete this file>',
        'Automatically generated by debmake'
    );

    my $regex = join($VERTICAL_BAR, @template);

    if ($readme =~ m/$regex/i) {
        $self->pointed_hint('readme-debian-contains-debmake-template',
            $item->pointer);

    } elsif ($readme =~ m/^\s*-- [^<]*<([^> ]+.\@[^>.]*)>/m) {

        my $address = $1;

        $self->pointed_hint('readme-debian-contains-invalid-email-address',
            $item->pointer, $address);
    }

    check_spelling($self->data,$readme,$group->spelling_exceptions,
        $self->spelling_tag_emitter('spelling-error-in-readme-debian', $item));

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
