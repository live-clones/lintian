# conffiles -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2017 Chris Lamb <lamby@debian.org>
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
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Conffiles;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use List::SomeUtils qw(any none);
use Path::Tiny;

const my $SPACE => q{ };

const my @KNOWN_INSTRUCTIONS => qw(remove-on-upgrade);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      if $self->processable->type =~ 'udeb';

    my $declared_conffiles = $self->processable->declared_conffiles;

    unless ($item->is_file) {
        $self->pointed_hint('conffile-has-bad-file-type', $item->pointer)
          if $declared_conffiles->is_known($item->name);
        return;
    }

    # files /etc must be conffiles, with some exceptions).
    $self->pointed_hint('file-in-etc-not-marked-as-conffile',$item->pointer)
      if $item->name =~ m{^etc/}
      && !$declared_conffiles->is_known($item->name)
      && $item->name !~ m{/README$}
      && $item->name !~ m{^ etc/init[.]d/ (?: skeleton | rc S? ) $}x;

    return;
}

sub binary {
    my ($self) = @_;

    my $declared_conffiles = $self->processable->declared_conffiles;
    for my $relative ($declared_conffiles->all) {

        my $item = $self->processable->conffiles_item;

        my @entries = @{$declared_conffiles->by_file->{$relative}};

        my @positions = map { $_->position } @entries;
        my $lines = join($SPACE, (sort { $a <=> $b } @positions));

        $self->pointed_hint('duplicate-conffile', $item->pointer,
            $relative, "(lines $lines)")
          if @entries > 1;

        for my $entry (@entries) {

            my $conffiles_item = $self->processable->conffiles_item;
            my $pointer = $conffiles_item->pointer($entry->position);

            $self->pointed_hint('relative-conffile', $pointer,$relative)
              if $entry->is_relative;

            $self->pointed_hint('file-in-etc-rc.d-marked-as-conffile',
                $pointer, $relative)
              if $relative =~ m{^etc/rc.\.d/};

            $self->pointed_hint('file-in-usr-marked-as-conffile',
                $pointer, $relative)
              if $relative =~ m{^usr/};

            $self->pointed_hint('non-etc-file-marked-as-conffile',
                $pointer, $relative)
              unless $relative =~ m{^etc/};

            my @instructions = @{$entry->instructions};

            my $instruction_lc
              = List::Compare->new(\@instructions, \@KNOWN_INSTRUCTIONS);
            my @unknown = $instruction_lc->get_Lonly;

            $self->pointed_hint('unknown-conffile-instruction', $pointer, $_)
              for @unknown;

            my $should_exist= none { $_ eq 'remove-on-upgrade' } @instructions;
            my $may_not_exist= any { $_ eq 'remove-on-upgrade' } @instructions;

            my $shipped = $self->processable->installed->lookup($relative);

            $self->pointed_hint('missing-conffile', $pointer, $relative)
              if $should_exist && !defined $shipped;

            $self->pointed_hint('unexpected-conffile', $pointer, $relative)
              if $may_not_exist && defined $shipped;
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
