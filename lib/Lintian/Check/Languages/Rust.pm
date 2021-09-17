# languages/rust -- lintian check script -*- perl -*-

# Copyright © 2020 Sylvestre Ledru
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

package Lintian::Check::Languages::Rust;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $debian_control = $self->processable->debian_control;
    for my $installable ($debian_control->installables) {

        my $fields = $debian_control->installable_fields($installable);
        my $extended = $fields->text('Description');

        # drop synopsis
        $extended =~ s/^ [^\n]* \n //sx;

        $self->hint('rust-boilerplate', $installable)
          if $extended
          =~ /^ \QThis package contains the following binaries built from the Rust crate\E /isx;
    }

    return;
}

sub installable {
    my ($self) = @_;

    $self->hint('empty-rust-library-declares-provides')
      if $self->processable->name =~ /^librust-/
      && $self->processable->not_just_docs
      && length $self->processable->fields->value('Provides');

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
