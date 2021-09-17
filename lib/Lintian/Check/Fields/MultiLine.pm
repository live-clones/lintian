# fields/multi-line -- lintian check script -*- perl -*-
#
# Copyright © 2019 Felix Lechner
#
# Parts of the code were taken from the old check script, which
# was Copyright © 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::Check::Fields::MultiLine;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $NEWLINE => qq{\n};

# based on policy 5.6
my @always_single = (
    qw(Architecture Bugs Changed-By Closes Date Distribution Dm-Upload-Allowed),
    qw(Essential Format Homepage Installed-Size Installer-Menu-Item Maintainer),
    qw(Multi-Arch Origin Package Priority Section Source Standards-Version),
    qw(Subarchitecture Urgency Version)
);

my @package_relations
  = (
    qw(Depends Pre-Depends Recommends Suggests Conflicts Provides Enhances Replaces Breaks)
  );

sub always {
    my ($self) = @_;

    my @banned = @always_single;

    # for package relations, multi-line only in source (policy 7.1)
    push(@banned, @package_relations)
      unless $self->processable->type eq 'source';

    my @present = $self->processable->fields->names;

    my $single_lc = List::Compare->new(\@present, \@banned);
    my @enforce = $single_lc->get_intersection;

    for my $name (@enforce) {

        my $value = $self->processable->fields->untrimmed_value($name);

        # remove a final newline, if any
        $value =~ s/\n$//;

        # check if fields have newlines in them
        $self->hint('multiline-field', $name)
          if index($value, $NEWLINE) >= 0;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
