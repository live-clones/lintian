# debian/variables -- lintian check script -*- perl -*-

# Copyright (C) 2006 Russ Allbery <rra@debian.org>
# Copyright (C) 2005 René van Bevern <rvb@pro-linux.de>
# Copyright (C) 2019-2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Debian::Variables;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(none);

const my @WANTED_FILES => (qr{ (.+ [.])? install }sx, qr{ (.+ [.])? links }sx);

const my @ILLEGAL_VARIABLES => qw(DEB_BUILD_MULTIARCH);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->name =~ m{^ debian/ }sx;

    return
      if none { $item->name =~ m{ / $_ $}sx } @WANTED_FILES;

    for my $variable (@ILLEGAL_VARIABLES) {

        $self->pointed_hint('illegal-variable', $item->pointer, $variable)
          if $item->decoded_utf8 =~ m{ \b $variable \b }msx;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
