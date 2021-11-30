# debian/lintian-overrides/duplicate -- lintian check script -*- perl -*-

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

package Lintian::Check::Debian::LintianOverrides::Duplicate;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $SPACE => q{ };

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub always {
    my ($self) = @_;

    my %pattern_tracker;
    push(@{$pattern_tracker{$_->tag_name}{$_->pattern}}, $_)
      for @{$self->processable->overrides};

    for my $tag_name (keys %pattern_tracker) {
        for my $pattern (keys %{$pattern_tracker{$tag_name}}) {

            my @overrides = @{$pattern_tracker{$tag_name}{$pattern}};

            my @same_context = map { $_->position } @overrides;
            my $line_numbers = join($SPACE, (sort @same_context));

            my $override_item = $self->processable->override_file;

            $self->pointed_hint('duplicate-override-context',
                $override_item->pointer,$tag_name,"(lines $line_numbers)")
              if @overrides > 1;
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
