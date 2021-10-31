# -*- perl -*-
# Lintian::Data -- interface to query lists of keywords

# Copyright © 2008 Russ Allbery
# Copyright © 2017-2018 Chris Lamb <lamby@debian.org>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Data;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use List::SomeUtils qw(any);
use Unicode::UTF8 qw(encode_utf8);

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $SLASH => q{/};

=head1 NAME

Lintian::Data - Lintian interface to query lists of keywords

=head1 SYNOPSIS

    my $keyword;
    my $list = Lintian::Data->new('type');
    if ($list->recognizes($keyword)) {
        # do something ...
    }
    my $hash = Lintian::Data->new('another-type', qr{\s++});
    if ($hash->value($keyword) > 1) {
        # do something ...
    }
    if ($list->value($keyword) > 1) {
        # do something ...
    }
    my @keywords = $list->all;
    if ($list->matches_any($keyword)) {
        # do something ...
    }

=head1 DESCRIPTION

Lintian::Data provides a way of loading a list of keywords or key/value
pairs from a file in the Lintian root and then querying that list.
The lists are stored in the F<data> directory of the Lintian root and
consist of one keyword or key/value pair per line.  Blank lines and
lines beginning with C<#> are ignored.  Leading and trailing whitespace
is stripped.

If requested, the lines are split into key/value pairs with a given
separator regular expression.  Otherwise, keywords are taken verbatim
as they are listed in the file and may include spaces.

This module allows lists such as menu sections, doc-base sections,
obsolete packages, package fields, and so forth to be stored in simple,
easily editable files.

NB: By default Lintian::Data is lazy and defers loading of the data
file until it is actually needed.

=head2 Interface for the CODE argument

This section describes the interface between for the CODE argument
for the class method new.

The sub will be called once for each key/pair with three arguments,
KEY, VALUE and CURVALUE.  The first two are the key/value pair parsed
from the data file and CURVALUE is current value associated with the
key.  CURVALUE will be C<undef> the first time the sub is called with
that KEY argument.

The sub can then modify VALUE in some way and return the new value for
that KEY.  If CURVALUE is not C<undef>, the sub may return C<undef> to
indicate that the current value should still be used.  It is not
permissible for the sub to return C<undef> if CURVALUE is C<undef>.

Where Perl semantics allow it, the sub can modify CURVALUE and the
changes will be reflected in the result.  As an example, if CURVALUE
is a hashref, new keys can be inserted etc.

=head1 INSTANCE METHODS

=over 4

=item dataset

=item C<keyorder>

=cut

has dataset => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has keyorder => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

=item all

Returns all keywords listed in the data file as a list in original order.
In a scalar context, returns the number of keywords.

=cut

sub all {
    my ($self) = @_;

    return @{$self->keyorder};
}

=item recognizes (KEY)

Returns true if KEY was listed in the data file represented by this
Lintian::Data instance and false otherwise.

=cut

sub recognizes {
    my ($self, $key) = @_;

    return 0
      unless length $key;

    return 1
      if exists $self->dataset->{$key};

    return 0;
}

=item resembles (KEY)

Returns true if the data file contains a key that is a case-insensitive match
to KEY, and false otherwise.

=cut

sub resembles {
    my ($self, $key) = @_;

    return 0
      unless length $key;

    return 1
      if $self->recognizes($key);

    return 1
      if any { m{^\Q$key\E$}i } keys %{$self->dataset};

    return 0;
}

=item value (KEY)

Returns the value attached to KEY if it was listed in the data
file represented by this Lintian::Data instance and the undefined value
otherwise.

=cut

sub value {
    my ($self, $key) = @_;

    return undef
      unless length $key;

    return $self->dataset->{$key};
}

=item matches_any(KEYWORD[, MODIFIERS])

Returns true if KEYWORD matches any regular expression listed in the
data file. The optional MODIFIERS serve as modifiers on all regexes.

=cut

sub matches_any {
    my ($self, $wanted, $modifiers) = @_;

    return 0
      unless length $wanted;

    $modifiers //= $EMPTY;

    return 1
      if any { $wanted =~ /(?$modifiers)$_/ } $self->all;

    return 0;
}

=item load

=cut

sub load {
    my ($self, $search_space, $our_vendor) = @_;

    my @remaining_lineage = @{$search_space // []};
    return 0
      unless @remaining_lineage;

    my $directory = shift @remaining_lineage;

    my $path = $directory . $SLASH . $self->location;
    unless (-e $path) {

        $self->load(\@remaining_lineage, $our_vendor)
          or croak encode_utf8('Unknown data file: ' . $self->location);

        return 1;
    }

    open(my $fd, '<:utf8_strict', $path)
      or die encode_utf8("Cannot open $path: $!");

    local $. = undef;
    while (my $line = <$fd>) {

        # trim both ends
        $line =~ s/^\s+|\s+$//g;

        next
          unless length $line;

        next
          if $line =~ m{^\#};

        # a command
        if ($line =~ s/^\@//) {

            my ($directive, $value) = split(/\s+/, $line, 2);
            if ($directive eq 'delete') {

                croak encode_utf8(
                    "Missing key after \@delete in $path at line $.")
                  unless length $value;

                @{$self->keyorder} = grep { $_ ne $value } @{$self->keyorder};
                delete $self->dataset->{$value};

            } elsif ($directive eq 'include-parent') {

                $self->load(\@remaining_lineage, $our_vendor)
                  or croak encode_utf8("No ancestor data file for $path");

            } elsif ($directive eq 'if-vendor-is'
                || $directive eq 'if-vendor-is-not') {

                my ($specified_vendor, $remain) = split(/\s+/, $value, 2);

                croak encode_utf8("Missing vendor name after \@$directive")
                  unless length $specified_vendor;
                croak encode_utf8(
                    "Missing command after vendor name for \@$directive")
                  unless length $remain;

                $our_vendor =~ s{/.*$}{};

                next
                  if $directive eq 'if-vendor-is'
                  && $our_vendor ne $specified_vendor;

                next
                  if $directive eq 'if-vendor-is-not'
                  && $our_vendor eq $specified_vendor;

                $line = $remain;
                redo;

            } else {
                croak encode_utf8(
                    "Unknown operation \@$directive in $path at line $.");
            }
            next;
        }

        my $key = $line;
        my $remainder;

        ($key, $remainder) = split($self->separator, $line, 2)
          if defined $self->separator;

        my $value;
        if (defined $self->accumulator) {

            my $previous = $self->dataset->{$key};
            $value = $self->accumulator->($key, $remainder, $previous);

            next
              unless defined $value;

        } else {
            $value = $remainder;
        }

        push(@{$self->keyorder}, $key)
          unless exists $self->dataset->{$key};

        $self->dataset->{$key} = $value;
    }

    close $fd;

    return 1;
}

=back

=head1 FILES

=over 4

=item LINTIAN_INCLUDE_DIR/data

The files loaded by this module must be located in this directory.
Relative paths containing a C</> are permitted, so files may be organized
in subdirectories in this directory.

Note that lintian supports multiple LINTIAN_INCLUDE_DIRs.

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), L<https://lintian.debian.org/manual/section-2.6.html>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
