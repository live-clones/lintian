# Lintian::Lab -- Perl laboratory functions for lintian

# Copyright (C) 2011 Niels Thykier
#   - Based on the work of "Various authors"  (Copyright 1998-2004)
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

package Lintian::Lab;

use strict;
use warnings;

use Moo;

use Carp qw(croak);
use Cwd();
use File::Temp qw(tempdir);
use Path::Tiny;

use constant EMPTY => q{};

=encoding utf8

=head1 NAME

Lintian::Lab -- Interface to the Lintian Lab

=head1 SYNOPSIS

 use Lintian::Lab;

 my $lab = Lintian::Lab->new;

=head1 DESCRIPTION

This module provides an abstraction from "How and where" packages are
placed.  It handles creation and deletion of the Lintian Lab itself as
well as providing access to the entries.

=over 4

=item $lab->basedir

Returns the base directory for the lab. Most likely it's a temporary directory.

=item $lab->keep

Returns or accepts a boolean value that indicates whether the lab should be
removed when Lintian finishes. Used for debugging.

=back

=cut

# must be absolute; frontend/lintian depends on it
has basedir => (
    is => 'rwp',
    default => sub {

        my $relative = tempdir('temp-lintian-lab-XXXXXXXXXX', 'TMPDIR' => 1);

        my $absolute = Cwd::abs_path($relative);
        croak "Could not resolve $relative: $!"
          unless $absolute;

        path("$absolute/pool")->mkpath({mode => 0777});

        return $absolute;
    });
has keep => (is => 'rw', default => 0);

=head1 INSTANCE METHODS

=over 4

=item DEMOLISH

Removes the lab and everything in it.  Any reference to an entry
returned from this lab will immediately become invalid.

=cut

sub DEMOLISH {
    my ($self, $in_global_destruction) = @_;

    path($self->basedir)->remove_tree
      if length $self->basedir && -d $self->basedir && !$self->keep;

    return;
}

=back

=head1 AUTHOR

Niels Thykier <niels@thykier.net>

Based on the work of various others.

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
