# languages/ocaml/byte-code/misplaced/path -- lintian check script -*- perl -*-
#
# Copyright © 2009 Stéphane Glondu
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

package Lintian::Check::Languages::Ocaml::ByteCode::Misplaced::Path;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(first_value);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SLASH => q{/};

has misplaced_files => (is => 'rw', default => sub { [] });

sub visit_installed_files {
    my ($self, $item) = @_;

    # development files outside /usr/lib/ocaml (.cmi, .cmx, .cmxa)
    return
      if $item->name =~ m{^ usr/lib/ocaml/ }x;

    # .cma, .cmo and .cmxs are excluded because they can be plugins
    push(@{$self->misplaced_files}, $item->name)
      if $item->name =~ m{ [.] cm (?: i | xa? ) $}x;

    return;
}

sub installable {
    my ($self) = @_;

    my $count = scalar @{$self->misplaced_files};
    my $plural = ($count == 1) ? $EMPTY : 's';

    my $prefix = longest_common_prefix(@{$self->misplaced_files});

    # strip trailing slash
    $prefix =~ s{ / $}{}x
      unless $prefix eq $SLASH;

    $self->hint(
        'ocaml-dev-file-not-in-usr-lib-ocaml',
        "$count file$plural in $prefix"
    )if $count > 0;

    return;
}

sub longest_common_prefix {
    my (@paths) = @_;

    my %prefixes;

    for my $path (@paths) {

        my $truncated = $path;

        # first operation drops the file name
        while ($truncated =~ s{ / [^/]* $}{}x) {
            ++$prefixes{$truncated};
        }
    }

    my @by_descending_length = reverse sort keys %prefixes;

    my $common = first_value { $prefixes{$_} == @paths } @by_descending_length;

    $common ||= $SLASH;

    return $common;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
