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

package Lintian::fields::multi_line;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::Compare;

use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Check';

# based on policy 5.6
my @always_single = (
    qw(architecture bugs changed-by closes date distribution dm-upload-allowed),
    qw(essential format homepage installed-size installer-menu-item maintainer),
    qw(multi-arch origin package priority section source standards-version),
    qw(subarchitecture urgency version)
);

my @package_relations
  = (
    qw(depends pre-depends recommends suggests conflicts provides enhances replaces breaks)
  );

sub always {
    my ($self) = @_;

    my @banned = @always_single;

    # for package relations, multi-line only in source (policy 7.1)
    push(@banned, @package_relations)
      unless $self->type eq 'source';

    my @present = keys %{$self->processable->field};

    my $single_lc = List::Compare->new('--unsorted', \@present, \@banned);
    my @enforce = $single_lc->get_intersection;

    for my $name (@enforce) {

        my $value = $self->processable->field($name);

        return
          unless length $value;

        # remove a final newline, if any
        $value =~ s/\n$//;

        # capitalize first letters
        $name =~ s/\b(\w)/\U$1/g;

        # check if fields have newlines in them
        $self->tag('multiline-field', $name)
          if index($value, NEWLINE) >= 0;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
