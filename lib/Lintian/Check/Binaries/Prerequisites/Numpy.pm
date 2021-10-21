# binaries/prerequisites/numpy -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2012 Kees Cook
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Binaries::Prerequisites::Numpy;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $NUMPY_REGEX => qr{
    \Qmodule compiled against ABI version \E (?:0x)?%x
    \Q but this version of numpy is \E (?:0x)?%x
}x;

has uses_numpy_c_abi => (is => 'rw', default => 0);

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      if $item->file_info !~ m{^ [^,]* \b ELF \b }x
      || $item->file_info !~ m{ \b executable | shared [ ] object \b }x;

    # Python extension using Numpy C ABI?
    if (   $item->name=~ m{^usr/lib/(?:pyshared/)?python2\.\d+/.*(?<!_d)\.so$}
        || $item->name
        =~ m{^ usr/lib/python3(?:[.]\d+)? / \S+ [.]cpython- \d+ - \S+ [.]so $}x
    ){
        $self->uses_numpy_c_abi(1)
          if $item->strings =~ / numpy /msx
          && $item->strings =~ $NUMPY_REGEX;
    }

    return;
}

sub installable {
    my ($self) = @_;

    return
      if $self->processable->type eq 'udeb';

    my $depends = $self->processable->relation('strong');

    # Check for dependency on python3-numpy-abiN dependency (or strict
    # versioned dependency on python3-numpy)
    # We do not allow alternatives as it would mostly likely
    # defeat the purpose of this relation.  Also, we do not allow
    # versions for -abi as it is a virtual package.
    $self->hint('missing-dependency-on-numpy-abi')
      if $self->uses_numpy_c_abi
      && !$depends->matches(qr/^python3?-numpy-abi\d+$/,
        Lintian::Relation::VISIT_OR_CLAUSE_FULL)
      && (
        !$depends->matches(
            qr/^python3-numpy \(>[>=][^\|]+$/,
            Lintian::Relation::VISIT_OR_CLAUSE_FULL
        )
        || !$depends->matches(
            qr/^python3-numpy \(<[<=][^\|]+$/,
            Lintian::Relation::VISIT_OR_CLAUSE_FULL
        ))&& $self->processable->name !~ m{\A python3?-numpy \Z}xsm;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
