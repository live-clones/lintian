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

package Lintian::Check::Fields::Maintainer::Team;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Email::Address::XS;
use List::SomeUtils qw(uniq first_value);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $ARROW => q{ » };

my %team_names = (
    'debian-go@lists.debian.org' => 'golang',
    'debian-clojure@lists.debian.org' => 'clojure',
    'pkg-java-maintainers@lists.alioth.debian.org' => 'java',
    'pkg-javascript-maintainers@lists.alioth.debian.org' => 'javascript',
    'pkg-perl-maintainers@lists.alioth.debian.org' => 'perl',
    'team+python@tracker.debian.org' => 'python'
);

sub source {
    my ($self) = @_;

    my $maintainer = $self->processable->fields->value('Maintainer');
    return
      unless length $maintainer;

    my $parsed = Email::Address::XS->parse($maintainer);
    return
      unless $parsed->is_valid;

    return
      unless length $parsed->address;

    my $team = $team_names{$parsed->address};
    return
      unless length $team;

    return
      if $self->name_contains($team);

    my @other_teams = uniq grep { $_ ne $team } values %team_names;

    my $name_suggests = first_value { $self->name_contains($_) } @other_teams;
    return
      unless length $name_suggests;

    $self->hint('wrong-team', $team . $ARROW . $name_suggests)
      unless $name_suggests eq $team;

    return;
}

sub name_contains {
    my ($self, $string) = @_;

    return $self->processable->name =~ m{ \b \Q$string\E \b }sx;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
