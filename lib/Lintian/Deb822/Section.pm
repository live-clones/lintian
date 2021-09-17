# Copyright © 2020 Felix Lechner
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

package Lintian::Deb822::Section;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;

const my $EMPTY => q{};

const my $UNKNOWN_POSITION => -1;

use Moo;
use namespace::clean;

=encoding utf-8

=head1 NAME

Lintian::Deb822::Section -- A paragraph in a control file

=head1 SYNOPSIS

 use Lintian::Deb822::Section;

=head1 DESCRIPTION

Represents a paragraph in a Deb822 control file.

=head1 INSTANCE METHODS

=over 4

=item legend

Returns exact field names for their lowercase versions.

=item verbatim

Returns a hash to the raw, unedited and verbatim field values.

=item unfolded

Returns a hash to unfolded field values. Continuations lines
have been connected.

=item positions

The original line positions.

=cut

has legend => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %legend;

        $legend{lc $_} = $_ for keys %{$self->verbatim};

        return \%legend;
    });

has verbatim => (is => 'rw', default => sub { {} });
has unfolded => (is => 'rw', default => sub { {} });
has positions => (is => 'rw', default => sub { {} });

=item trimmed_list(FIELD [, SEPARATOR])

=cut

sub trimmed_list {
    my ($self, $name, $regex) = @_;

    $regex //= qr/\s+/;

    my $value = $self->value($name);

    # trim both ends
    $value =~ s/^\s+|\s+$//g;

    my @list = split($regex, $value);

    # trim both ends of each element
    s/^\s+|\s+$//g for @list;

    return grep { length } @list;
}

=item unfolded_value (FIELD)

This method returns the unfolded value of the control field FIELD in
the control file for the package.  For a source package, this is the
*.dsc file; for a binary package, this is the control file in the
control section of the package.

If FIELD is passed but not present, then this method returns undef.

=cut

sub unfolded_value {
    my ($self, $name) = @_;

    return $EMPTY
      unless length $name;

    my $lowercase = lc $name;

    my $unfolded = $self->unfolded->{$lowercase};
    return $unfolded
      if defined $unfolded;

    my $value = $self->value($name);

    # will also replace a newline at the very end
    $value =~ s/\n//g;

    # Remove leading space as it confuses some of the other checks
    # that are anchored.  This happens if the field starts with a
    # space and a newline, i.e ($ marks line end):
    #
    # Vcs-Browser: $
    #  http://somewhere.com/$
    $value =~ s/^\s*+//;

    $self->unfolded->{$lowercase} = $value;

    return $value;
}

=item value (FIELD)

If FIELD is given, this method returns the value of the control field
FIELD.

=cut

sub value {
    my ($self, $name) = @_;

    return $EMPTY
      unless length $name;

    my $exact = $self->legend->{lc $name};
    return $EMPTY
      unless length $exact;

    my $trimmed = $self->verbatim->{$exact} // $EMPTY;

    # trim both ends
    $trimmed =~ s/^\s+|\s+$//g;

    return $trimmed;
}

=item untrimmed_value (FIELD)

If FIELD is given, this method returns the value of the control field
FIELD.

=cut

sub untrimmed_value {
    my ($self, $name) = @_;

    return $EMPTY
      unless length $name;

    my $exact = $self->legend->{lc $name};
    return $EMPTY
      unless length $exact;

    return $self->verbatim->{$exact} // $EMPTY;
}

=item text (FIELD)

=cut

sub text {
    my ($self, $name) = @_;

    my $text = $self->untrimmed_value($name);

    # remove leading space in each line
    $text =~ s/^[ \t]//mg;

    # remove dot place holder for empty lines
    $text =~ s/^\.$//mg;

    return $text;
}

=item store (FIELD, VALUE)

=cut

sub store {
    my ($self, $name, $value) = @_;

    $value //= $EMPTY;

    return
      unless length $name;

    my $exact = $self->legend->{lc $name};

    # add new value if key not found
    unless (defined $exact) {

        $exact = $name;

        # update legend with exact spelling
        $self->legend->{lc $exact} = $exact;

        # remove any old position
        $self->positions->{$exact} = $UNKNOWN_POSITION;
    }

    $self->verbatim->{$exact} = $value;

    # remove old unfolded value, if any
    delete $self->unfolded->{$exact};

    return;
}

=item drop (FIELD)

=cut

sub drop {
    my ($self, $name) = @_;

    return
      unless length $name;

    my $exact = $self->legend->{lc $name};
    return
      unless length $exact;

    delete $self->legend->{lc $exact};

    delete $self->verbatim->{$exact};
    delete $self->unfolded->{$exact};
    delete $self->positions->{$exact};

    return;
}

=item declares (NAME)

Returns a boolean for whether the named field exists.

=cut

sub declares {
    my ($self, $name) = @_;

    return 1
      if defined $self->legend->{lc $name};

    return 0;
}

=item names

Returns an array with the literal field names.

=cut

sub names {
    my ($self) = @_;

    return keys %{$self->verbatim};
}

=item literal_name

Returns an array with the literal, true case field names.

=cut

sub literal_name {
    my ($self, $anycase) = @_;

    return $self->legend->{ lc $anycase };
}

=item position

With an argument, returns the starting line of the named field.

Without an argument, return the starting line of the paragraph.

=cut

sub position {
    my ($self, $field) = @_;

    return $self->positions->{'START-OF-PARAGRAPH'}
      unless length $field;

    my $exact = $self->legend->{lc $field};
    return undef
      unless length $exact;

    return $self->positions->{$exact};
}

=item extra

=cut

sub extra {
    my ($self, @reference) = @_;

    my @lowercase = map { lc } @reference;

    my $extra_lc
      = List::Compare->new([keys %{$self->legend}], \@lowercase);
    my @extra_lowercase = $extra_lc->get_Lonly;

    my @extra = map { $self->literal_name($_) } @extra_lowercase;

    return @extra;
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
