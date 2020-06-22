# Copyright © 2019 Felix Lechner <felix.lechner@lease-up.com>
# Copyright © 2017-2018 Chris Lamb <lamby@debian.org>
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

package Lintian::Check;

use v5.20;
use warnings;
use utf8;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Check -- Common facilities for Lintian checks

=head1 SYNOPSIS

 use Moo;
 use namespace::clean;

 with('Lintian::Check');

=head1 DESCRIPTION

A class for collecting Lintian tags as they are issued

=head1 INSTANCE METHODS

=over 4

=item processable

Get processable underlying this check.

=item group

Get group that the processable is in.

=item info

Check::Info structure for this check.

=cut

has processable => (is => 'rw', default => sub { {} });
has group => (is => 'rw', default => sub { {} });
has info => (is => 'rw');

=item visit

=cut

sub visit {
    my ($self, $index) = @_;

    my $setup_hook = "setup_$index";
    $self->$setup_hook
      if $self->can($setup_hook);

    my $visit_hook = "visit_$index";
    if ($self->can($visit_hook)) {

        $self->$visit_hook($_) for $self->processable->$index->sorted_list;
    }

    my $breakdown_hook = "breakdown_$index";
    $self->$breakdown_hook
      if $self->can($breakdown_hook);

    return;
}

=item run

Run the check.

=cut

sub run {
    my ($self) = @_;

    my $type = $self->processable->type;

    $self->visit('patched')
      if $type eq 'source';

    if ($type eq 'binary' || $type eq 'udeb') {

        $self->visit('control');

        $self->visit('installed');

        $self->setup
          if $self->can('setup');

        if ($self->can('files')) {
            $self->files($_) for $self->processable->installed->sorted_list;
        }

        $self->breakdown
          if $self->can('breakdown');

        $self->installable
          if $self->can('installable');
    }

    $self->$type
      if $self->can($type);

    $self->always
      if $self->can('always');

    return;
}

=item tag

Tag the processable associated with this check

=cut

sub tag {
    my ($self, @arguments) = @_;

    return
      unless @arguments;

    my $tagname = $arguments[0];

    warn 'Check ' . $self->info->name . " has no tag $tagname."
      unless defined $self->info->get_tag($tagname);

    return $self->processable->tag(@arguments);
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
