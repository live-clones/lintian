# shell/csh -- lintian check script -*- perl -*-
#
# Copyright © 1998 Richard Braakman
# Copyright © 2002 Josip Rodin
# Copyright © 2016-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Shell::Csh;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

sub visit_installed_files {
    my ($self, $item) = @_;

    # Consider /usr/src/ scripts as "documentation"
    # - packages containing /usr/src/ tend to be "-source" .debs
    #   and usually come with overrides
    # no checks necessary at all for scripts in /usr/share/doc/
    # unless they are examples
    return
      if ($item->name =~ m{^usr/share/doc/} || $item->name =~ m{^usr/src/})
      && $item->name !~ m{^usr/share/doc/[^/]+/examples/};

    $self->hint('csh-considered-harmful', $item->name,
        $LEFT_PARENTHESIS . $item->interpreter . $RIGHT_PARENTHESIS)
      if $self->is_csh_script($item)
      && $item->name !~ m{^ etc/csh/login[.]d/ }x;

    return;
}

sub visit_control_files {
    my ($self, $item) = @_;

    # perhaps we should warn about *csh even if they're somehow screwed,
    # but that's not really important...
    $self->hint('csh-considered-harmful', "control/$item",
        $LEFT_PARENTHESIS . $item->interpreter . $RIGHT_PARENTHESIS)
      if $self->is_csh_script($item);

    return;
}

sub is_csh_script {
    my ($self, $item) = @_;

    return 0
      unless length $item->interpreter;

    my $basename = basename($item->interpreter);

    return 1
      if $basename eq 'csh' || $basename eq 'tcsh';

    return 0;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
