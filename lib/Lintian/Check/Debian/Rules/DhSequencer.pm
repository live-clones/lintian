# debian/rules/dh-sequencer -- lintian check script -*- perl -*-

# Copyright © 2019 Felix Lechner
# Copyright © 2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Debian::Rules::DhSequencer;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $processable = $self->processable;
    my $group = $self->group;

    my $rules = $processable->patched->resolve_path('debian/rules');
    return
      unless $rules;

    my $contents = $rules->bytes;

    # strip comments (see #960485)
    $contents =~ s/^\h#.*\R?//mg;

    my $plain = qr/\$\@/;
    my $curly = qr/\$\{\@\}/;
    my $asterisk = qr/\$\*/;
    my $parentheses = qr/\$\(\@\)/;
    my $rule_altern = qr/(?:$plain|$curly|$asterisk|$parentheses)/;
    my $rule_target = qr/(?:$rule_altern|'$rule_altern'|"$rule_altern")/;

    $self->hint('no-dh-sequencer')
      unless $contents =~ /^\t+(?:[\+@-])?(?:[^=]+=\S+ )?dh[ \t]+$rule_target/m
      || $contents =~ m{^\s*include\s+/usr/share/cdbs/1/class/hlibrary.mk\s*$}m
      || $contents =~ m{\bDEB_CABAL_PACKAGE\b};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
