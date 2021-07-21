# Copyright © 2011 Niels Thykier <niels@thykier.net>
# Copyright © 2019-2020 Felix Lechner
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

package Lintian::Processable;

use v5.20;
use warnings;
use utf8;
use warnings::register;

use Const::Fast;
use Path::Tiny;

use Moo::Role;
use MooX::Aliases;
use namespace::clean;

with 'Lintian::Hint::Bearer';

const my $EMPTY => q{};
const my $COLON => q{:};
const my $SLASH => q{/};
const my $UNDERSCORE => q{_};
const my $EVIL_CHARACTERS => qr{[/&|;\$"'<>]};

=encoding utf-8

=head1 NAME

Lintian::Processable -- An (abstract) object that Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable;

=head1 DESCRIPTION

Instances of this perl class are objects that Lintian can process (e.g.
deb files).  Multiple objects can then be combined into
L<groups|Lintian::Group>, which Lintian will process
together.

=head1 INSTANCE METHODS

=over 4

=item name

Returns the name of the package.

=item type

Returns the type of package (e.g. binary, source, udeb ...)

=item $proc->version

Returns the version of the package.

=item $proc->path

Returns the path to the packaged version of actual package.  This path
is used in case the data needs to be extracted from the package.

=item $proc->architecture

Returns the architecture(s) of the package. May return multiple values
from changes processables.  For source processables it is "source".

=item $proc->source_name

Returns the name of the source package.

=item $proc->source_version

Returns the version of the source package.

=item $proc->tainted

Returns a truth value if one or more fields in this Processable is
tainted.  On a best effort basis tainted fields will be sanitized
to less dangerous (but possibly invalid) values.

=item fields

Lintian::Deb822::Section with primary field values.

=item $proc->pooldir

Returns a reference to lab this Processable is in.

=item $proc->basedir

Returns the base directory of this package inside the lab.

=cut

has path => (is => 'rw', default => $EMPTY);
has type => (is => 'rw', default => $EMPTY);

has architecture => (
    is => 'rw',
    coerce => sub {
        my ($value) = @_;
        return clean_field($value);
    },
    default => $EMPTY
);
has name => (
    is => 'rw',
    coerce => sub {
        my ($value) = @_;
        return clean_field($value);
    },
    default => $EMPTY
);
has source_name => (
    is => 'rw',
    coerce => sub {
        my ($value) = @_;
        return clean_field($value);
    },
    default => $EMPTY
);
has source_version =>(
    is => 'rw',
    coerce => sub {
        my ($value) = @_;
        return clean_field($value);
    },
    default => $EMPTY
);
has version => (
    is => 'rw',
    coerce => sub {
        my ($value) = @_;
        return clean_field($value);
    },
    default => $EMPTY
);

has tainted => (is => 'rw', default => 0);

has fields => (is => 'rw', default => sub { Lintian::Deb822::Section->new; });

has pooldir => (is => 'rw', default => $EMPTY);
has basedir => (
    is => 'rw',
    lazy => 1,
    trigger => sub {
        my ($self, $folder) = @_;

        return
          unless length $folder;

        # create directory
        path($folder)->mkpath
          unless -e $folder;
    },
    default => sub {
        my ($self) = @_;

        my $path
          = $self->source_name
          . $SLASH
          . $self->name
          . $UNDERSCORE
          . $self->version;
        $path .= $UNDERSCORE . $self->architecture
          unless $self->type eq 'source';
        $path .= $UNDERSCORE . $self->type;

        # architectures can contain spaces in changes files
        $path =~ s/\s/-/g;

        # colon can be a path separator
        $path =~ s/:/_/g;

        my $basedir = $self->pooldir . "/$path";

        return $basedir;
    });

=item C<identifier>

Produces an identifier for this processable.  The identifier is
based on the type, name, version and architecture of the package.

=cut

sub identifier {
    my ($self) = @_;

    my $id = $self->type . $COLON . $self->name . $UNDERSCORE . $self->version;

    # add architecture unless it is source
    $id .= $UNDERSCORE . $self->architecture
      unless $self->type eq 'source';

    $id =~ s/\s+/_/g;

    return $id;
}

=item remove

Removes all unpacked parts of the package in the lab.  Returns a truth
value if successful.

=cut

sub remove {
    my ($self) = @_;

    path($self->basedir)->remove_tree
      if -e $self->basedir;

    return;
}

=item clean_field

Cleans a field of evil characters to prevent traversal or worse.

=cut

sub clean_field {
    my ($value) = @_;

    # make sure none of the fields can cause traversal
    my $clean = $value;
    $clean =~ s/${$EVIL_CHARACTERS}/_/g;

    return $clean;
}

=item guess_name

=cut

sub guess_name {
    my ($self, $path) = @_;

    my $guess = path($path)->basename;

    # drop extension, to catch fields-general-missing.deb
    $guess =~ s/\.[^.]*$//;

    # drop everything after the first underscore, if any
    $guess =~ s/_.*$//;

    # 'path/lintian_2.5.2_amd64.changes' became 'lintian'
    return $guess;
}

=item unfolded_field (FIELD)

This method returns the unfolded value of the control field FIELD in
the control file for the package.  For a source package, this is the
*.dsc file; for a binary package, this is the control file in the
control section of the package.

If FIELD is passed but not present, then this method returns undef.

=cut

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.
Substantial portions written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintian::Processable::Installable>

L<Lintian::Processable::Buildinfo>

L<Lintian::Processable::Changes>

L<Lintian::Processable::Source>

L<Lintian::Group>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
