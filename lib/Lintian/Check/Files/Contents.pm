# files/contents -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2019 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020 Felix Lechner
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

package Lintian::Check::Files::Contents;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SLASH => q{/};
const my $ARROW => q{ -> };

my $SENSIBLE_REGEX
  = qr{(?<!-)(?:select-editor|sensible-(?:browser|editor|pager))\b};

# with this Moo default, maintainer scripts are also checked
has switched_locations => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @files
          = grep { $_->is_file } @{$self->processable->installed->sorted_list};

        my @commands = grep { $_->name =~ m{^(?:usr/)?s?bin/} } @files;

        my %switched_locations;
        for my $command (@commands) {

            my @variants = map { $_ . $SLASH . $command->basename }
              qw(bin sbin usr/bin usr/sbin);
            my @confused = grep { $_ ne $command->name } @variants;

            $switched_locations{$_} = $command->name for @confused;
        }

        return \%switched_locations;
    }
);

sub build_path {
    my ($self) = @_;

    my $buildinfo = $self->group->buildinfo;

    return $EMPTY
      unless $buildinfo;

    return $buildinfo->fields->value('Build-Path');
}

sub check_item {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    unless ($self->processable->relation('all')->satisfies('sensible-utils')
        || $self->processable->source_name eq 'sensible-utils') {

        my $sensible = $item->mentions_in_operation($SENSIBLE_REGEX);
        $self->pointed_hint('missing-depends-on-sensible-utils',
            $item->pointer, $sensible)
          if length $sensible;
    }

    unless ($self->processable->fields->value('Section') eq 'debian-installer'
        || any { $_ eq $self->processable->source_name } qw(base-files dpkg)) {

        $self->pointed_hint('uses-dpkg-database-directly', $item->pointer)
          if length $item->mentions_in_operation(qr{/var/lib/dpkg});
    }

    # if we have a /usr/sbin/foo, check for references to /usr/bin/foo
    my %switched_locations = %{$self->switched_locations};
    for my $confused (keys %switched_locations) {

  # may not work as expected on ELF due to ld's SHF_MERGE
  # but word boundaries are also superior in strings spanning multiple commands
        my $correct = $switched_locations{$confused};
        $self->pointed_hint('bin-sbin-mismatch', $item->pointer,
            $confused . $ARROW . $correct)
          if length $item->mentions_in_operation(qr{ \B / \Q$confused\E \b }x);
    }

    if (length $self->build_path) {
        my $escaped_path = quotemeta($self->build_path);
        $self->pointed_hint('file-references-package-build-path',
            $item->pointer)
          if $item->bytes_match(qr{$escaped_path});
    }

    return;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    $self->check_item($item);

    return;
}

sub visit_control_files {
    my ($self, $item) = @_;

    return
      unless $item->is_maintainer_script;

    $self->check_item($item);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
