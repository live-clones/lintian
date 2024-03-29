# binaries/prerequisites/php -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2012 Kees Cook
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Binaries::Prerequisites::Php;

use v5.20;
use warnings;
use utf8;

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has has_php_ext => (is => 'rw', default => 0);

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      if $item->file_type !~ m{^ [^,]* \b ELF \b }x
      || $item->file_type !~ m{ \b executable | shared [ ] object \b }x;

    # PHP extension?
    $self->has_php_ext(1)
      if $item->name =~ m{^usr/lib/php\d/.*\.so(?:\.\d+)*$};

    return;
}

sub installable {
    my ($self) = @_;

    return
      if $self->processable->type eq 'udeb';

    my $depends = $self->processable->relation('strong');

    # It is a virtual package, so no version is allowed and
    # alternatives probably does not make sense here either.
    $self->hint('missing-dependency-on-phpapi')
      if $self->has_php_ext
      && !$depends->matches(qr/^phpapi-[\d\w+]+$/,
        Lintian::Relation::VISIT_OR_CLAUSE_FULL);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
