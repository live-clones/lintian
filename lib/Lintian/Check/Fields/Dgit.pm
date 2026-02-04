# fields/dgit -- lintian check script -*- perl -*-
#
# Copyright (C) 2025 Maytham Alsudany <maytham@debian.org>
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

package Lintian::Check::Fields::Dgit;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $EMPTY => q{};
const my $QUESTION_MARK => q{?};

const my $NOT_EQUALS => q{!=};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub changes {
    my ($self) = @_;
    my $processable = $self->processable;

    return unless $processable->fields->declares("Dgit");
    my $dgit = $processable->fields->value("Dgit");

    $self->hint('uploaded-with-dgit');

    $self->hint('bad-dgit-in-changes-file', $dgit)
      unless $dgit =~ m/[a-z0-9]{40} \S+ \S+ https?:\/\/[a-z]+\.\S+/;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
