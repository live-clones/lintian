# lintian/override/comments -- lintian check script -*- perl -*-

# Copyright © 2020 Felix Lechner
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

package Lintian::lintian::override::comments;

use v5.20;
use warnings;
use utf8;
use autodie;

use POSIX qw(ENOENT);

use Lintian::Spelling qw(check_spelling check_spelling_picky);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub always {
    my ($self) = @_;

    my $declared_overrides = $self->processable->overrides;
    return
      unless defined $declared_overrides;

    for my $tagname (keys %{$declared_overrides}) {

        for my $context (keys %{$declared_overrides->{$tagname}}) {

            my $entry = $declared_overrides->{$tagname}{$context};
            my $line = $entry->{line};
            my @comments = @{$entry->{comments}};

            check_spelling(
                $_,
                $self->group->spelling_exceptions,
                $self->emitter(
                    'spelling-in-override-comment',
                    "$tagname (line $line)"
                ))for @comments;

            check_spelling_picky(
                $_,
                $self->emitter(
                    'capitalization-in-override-comment',
                    "$tagname (line $line)"
                ))for @comments;
        }
    }

    return;
}

sub emitter {
    my ($self, @orig_args) = @_;

    return sub {
        return $self->tag(@orig_args, @_);
    };
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
