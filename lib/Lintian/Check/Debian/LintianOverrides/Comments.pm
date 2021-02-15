# debian/lintian-overrides/comments -- lintian check script -*- perl -*-

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

package Lintian::Check::Debian::LintianOverrides::Comments;

use v5.20;
use warnings;
use utf8;

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

            my @comments = @{$entry->{comments}};
            my $override_position = $entry->{line};

            my $position = $override_position - scalar @comments;
            for my $comment (@comments) {

                check_spelling(
                    $self->profile,
                    $comment,
                    $self->group->spelling_exceptions,
                    $self->emitter(
                        'spelling-in-override-comment',
                        "$tagname (line $position)"
                    ));

                check_spelling_picky(
                    $self->profile,
                    $comment,
                    $self->emitter(
                        'capitalization-in-override-comment',
                        "$tagname (line $position)"
                    ));
            } continue {
                $position++;
            }
        }
    }

    return;
}

sub emitter {
    my ($self, @orig_args) = @_;

    return sub {
        return $self->hint(@orig_args, @_);
    };
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
