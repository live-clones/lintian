# Copyright © 2019 Felix Lechner
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

package Lintian::Output::Universal;

use strict;
use warnings;
use v5.12;

use Carp;
use List::MoreUtils qw(all);

use constant SPACE => q{ };
use constant EMPTY => q{};
use constant COLON => q{:};
use constant LPARENS => q{(};
use constant RPARENS => q{)};
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Output';

=head1 NAME

Lintian::Output::Universal -- Facilities for printing universal tags

=head1 SYNOPSIS

 use Lintian::Output::Universal;

=head1 DESCRIPTION

A class for printing tags using the 'universal' format.

=head1 INSTANCE METHODS

=over 4

=item issue_tags

Print all tags passed in array. A separate arguments with processables
is necessary to report in case no tags were found.

=cut

sub issue_tags {
    my ($self, $pending, $processables) = @_;

    return
      unless $pending && $processables;

    my %taglist;

    for my $tag (@{$pending}) {
        $taglist{$tag->processable} //= [];
        push(@{$taglist{$tag->processable}}, $tag);
    }

    my @lines;

    for my $processable (@{$processables}) {

        my $object = 'package';
        $object = 'file'
          if $processable->type eq 'changes';

        $self->v_msg(
            $self->delimiter,
            'Processing '. $processable->type. " $object ". $processable->name,
            '(version '
              . $processable->pkg_version
              . ', arch '
              . $processable->pkg_arch . ') ...'
        );

        my @subset = @{$taglist{$processable} // []};

        for my $tag (@subset) {

            my $details = $tag->extra;

            my $line
              = $processable->name
              . SPACE
              . LPARENS
              . $processable->type
              . RPARENS
              . COLON
              . SPACE
              . $tag->name;
            $line .= SPACE . $details
              if length $details;

            push(@lines, $line);
        }
    }

    my @sorted
      = reverse sort { order($a) cmp order($b) } @lines;

    print { $self->stdout } $_ . NEWLINE for @sorted;

    return;
}

sub _message {
    my ($self, @args) = @_;
    return;
}

sub _warning {
    my ($self, @args) = @_;
    return;
}

=item order

=cut

sub order {
    my ($line) = @_;

    return package_type($line) . $line;
}

=item package_type

=cut

sub package_type {
    my ($line) = @_;

    my (undef, $type, undef, undef) = parse_line($line);
    return $type;
}

=item parse_line

=cut

sub parse_line {
    my ($line) = @_;

    my ($package, $type, $name, $details)
      = $line =~ qr/^(\S+)\s+\(([^)]+)\):\s+(\S+)(?:\s+(.*))?$/;

    croak "Cannot parse line $line"
      unless all { length } ($package, $type, $name);

    return ($package, $type, $name, $details);
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
