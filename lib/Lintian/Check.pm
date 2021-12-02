# Copyright © 2012 Niels Thykier <niels@thykier.net>
# Copyright © 2017-2018 Chris Lamb <lamby@debian.org>
# Copyright © 2019-2021 Felix Lechner <felix.lechner@lease-up.com>
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

use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Hint::Annotated;
use Lintian::Hint::Pointed;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $UNDERSCORE => q{_};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Check -- Common facilities for Lintian checks

=head1 SYNOPSIS

 use Moo;
 use namespace::clean;

 with('Lintian::Check');

=head1 DESCRIPTION

A class for operating Lintian checks

=head1 INSTANCE METHODS

=over 4

=item name

=item processable

=item group

=item profile

=item hints

=cut

has name => (is => 'rw', default => $EMPTY);
has processable => (is => 'rw', default => sub { {} });
has group => (is => 'rw', default => sub { {} });
has profile => (is => 'rw');

has hints => (is => 'rw', default => sub { [] });

=item visit_files

=cut

sub visit_files {
    my ($self, $index) = @_;

    my $visit_hook = 'visit' . $UNDERSCORE . $index . $UNDERSCORE . 'files';

    return
      unless $self->can($visit_hook);

    my @items = @{$self->processable->$index->sorted_list};

    # do not look inside quilt directory
    @items = grep { $_->name !~ m{^\.pc/} } @items
      if $index eq 'patched';

    # exclude Lintian's test suite from source scans
    @items = grep { $_->name !~ m{^t/} } @items
      if $self->processable->name eq 'lintian' && $index eq 'patched';

    $self->$visit_hook($_) for @items;

    return;
}

=item run

=cut

sub run {
    my ($self) = @_;

    # do not carry over any hints
    $self->hints([]);

    my $type = $self->processable->type;

    if ($type eq 'source') {

        $self->visit_files('orig');
        $self->visit_files('patched');
    }

    if ($type eq 'binary' || $type eq 'udeb') {

        $self->visit_files('control');
        $self->visit_files('installed');

        $self->installable
          if $self->can('installable');
    }

    $self->$type
      if $self->can($type);

    $self->always
      if $self->can('always');

    return @{$self->hints};
}

=item pointed_hint

=cut

sub pointed_hint {
    my ($self, $tag_name, $pointer, @notes) = @_;

    my $hint = Lintian::Hint::Pointed->new;

    $hint->tag_name($tag_name);
    $hint->issued_by($self->name);
    $hint->notes(\@notes);
    $hint->pointer($pointer);

    push(@{$self->hints}, $hint);

    return;
}

=item hint

=cut

sub hint {
    my ($self, $tag_name, @notes) = @_;

    my $hint = Lintian::Hint::Annotated->new;

    $hint->tag_name($tag_name);
    $hint->issued_by($self->name);
    $hint->notes(\@notes);

    push(@{$self->hints}, $hint);

    return;
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
