# -*- perl -*-
# Lintian::Collect -- interface to package data collection

# Copyright © 2008 Russ Allbery
# Copyright © 2019 Felix Lechner
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

package Lintian::Collect;

use strict;
use warnings;
use warnings::register;

use Carp qw(croak);

use Lintian::Tags qw(tag);
use Lintian::Util qw(get_dsc_info get_deb_info);

use constant SLASH => q{/};

use Moo::Role;
use namespace::clean;

=encoding utf-8

=head1 NAME

Lintian::Collect - Lintian interface to package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'udeb', '/some/abs/path');
    my $collect = Lintian::Collect::Binary->new_object($name);
    $name = $collect->name;
    $type = $collect->type;

=head1 DESCRIPTION

Lintian::Collect provides the shared interface to package data used by
source, binary and udeb packages and .changes files.  It creates an
object of the appropriate type and provides common functions used by the
collection interface to all types of package.

Usually instances should not be created directly (exceptions include
collections), but instead be requested via the
L<info|Lintian::Lab::Entry/info> method in Lintian::Lab::Entry.

This module is in its infancy.  Most of Lintian still reads all data from
files in the laboratory whenever that data is needed and generates that
data via collect scripts.  The goal is to eventually access all data via
this module and its subclasses so that the module can cache data where
appropriate and possibly retire collect scripts in favor of caching that
data in memory.

=head1 CLASS METHODS

=over 4

=back

=head1 INSTANCE METHODS

In addition to the instance methods documented here, see the documentation
of L<Lintian::Collect::Source>, L<Lintian::Collect::Binary> and
L<Lintian::Collect::Changes> for instance methods specific to source and
binary / udeb packages and .changes files.

=over 4

=item name

Returns the name of the package.

=item type

Returns the type of the package.

=item base_dir

Returns the base_dir where all the package information is stored.

=item verbatim

Returns a hash to the raw, unedited and verbatim field values.

=item unfolded

Returns a hash to unfolded field values. Continuations lines
have been connected.

=item shared_storage

Returns shared_storage.

=cut

has name => (is => 'rw');
has type => (is => 'rw');
has base_dir => (is => 'rw');

has verbatim => (is => 'rw', default => sub { {} });
has unfolded => (is => 'rwp', default => sub { {} });
has shared_storage => (is => 'rwp', default => sub { {} });

=item lab_data_path ([ENTRY])

Return the path to the ENTRY in the lab.  This is a convenience method
around base_dir.  If ENTRY is not given, this method behaves like
base_dir.

Needs-Info requirements for using I<lab_data_path>: L</base_dir>

=cut

sub lab_data_path {
    my ($self, $entry) = @_;

    croak 'Need entry to calculate lab data path.'
      unless $entry;

    return $self->base_dir . SLASH . $entry;
}

=item unfolded_field (FIELD)

This method returns the unfolded value of the control field FIELD in
the control file for the package.  For a source package, this is the
*.dsc file; for a binary package, this is the control file in the
control section of the package.

If FIELD is passed but not present, then this method returns undef.

Needs-Info requirements for using I<unfolded_field>: none

=cut

sub unfolded_field {
    my ($self, $field) = @_;

    return
      unless defined $field;

    return $self->unfolded->{$field}
      if exists $self->unfolded->{$field};

    my $value = $self->field($field);

    return
      unless defined $value;

    $value =~ s/\n$//;
    if ($value =~ s/\n//g) {

        tag 'multiline-field', $field;

        # Remove leading space as it confuses some of the other checks
        # that are anchored.  This happens if the field starts with a
        # space and a newline, i.e ($ marks line end):
        #
        # Vcs-Browser: $
        #  http://somewhere.com/$
        $value =~ s/^\s*+//;
    }

    $self->unfolded->{$field} = $value;

    return $value;
}

=item field ([FIELD[, DEFAULT]])

If FIELD is given, this method returns the value of the control field
FIELD in the control file for the package.  For a source package, this
is the *.dsc file; for a binary package, this is the control file in
the control section of the package.

If FIELD is passed but not present, then this method will return
DEFAULT (if given) or undef.

Otherwise this will return a hash of fields, where the key is the field
name (in all lowercase).

Needs-Info requirements for using I<field>: none

=cut

sub field {
    my ($self, $field, $default) = @_;

    unless (keys %{$self->verbatim}) {

        my $base_dir = $self->base_dir;
        my $verbatim;

        if ($self->type eq 'changes' || $self->type eq 'source'){
            my $file = 'changes';
            $file = 'dsc'
              if $self->type eq 'source';

            $verbatim = get_dsc_info("$base_dir/$file");

        } elsif ($self->type eq 'binary' || $self->type eq 'udeb'){
            # (ab)use the unpacked control dir if it is present
            if (   -f "$base_dir/control/control"
                && -s "$base_dir/control/control") {

                $verbatim = get_dsc_info("$base_dir/control/control");

            } else {
                $verbatim = (get_deb_info("$base_dir/deb"));
            }
        }

        $self->verbatim($verbatim);
    }

    return $self->verbatim
      unless defined $field;

    return $self->verbatim->{$field} // $default;
}

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Collect::Binary>, L<Lintian::Collect::Changes>,
L<Lintian::Collect::Source>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
