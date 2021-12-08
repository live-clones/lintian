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

    my @declared_overrides = @{$self->processable->overrides};

    for my $override (@declared_overrides) {

        my $tag_name = $override->tag_name;
        my @comments = @{$override->comments};

        my $position = $override->position - scalar @{$override->comments};
        for my $comment (@comments) {

            my $pointer= $self->processable->override_file->pointer($position);

            check_spelling(
                $self->data,
                $comment,
                $self->group->spelling_exceptions,
                $self->emitter(
                    'spelling-in-override-comment',
                    $pointer, $tag_name
                ));

            check_spelling_picky(
                $self->data,
                $comment,
                $self->emitter(
                    'capitalization-in-override-comment',
                    $pointer,$tag_name
                ));

        } continue {
            $position++;
        }
    }

    return;
}

sub emitter {
    my ($self, @prefixed) = @_;

    return sub {
        return $self->pointed_hint(@prefixed, @_);
    };
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
