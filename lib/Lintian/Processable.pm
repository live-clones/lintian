# Copyright © 2011 Niels Thykier <niels@thykier.net>
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

package Lintian::Processable;

use strict;
use warnings;
use warnings::register;

use Carp qw(croak);
use Path::Tiny;

use Lintian::Collect::Dispatcher qw(create_info);
use Lintian::Tags qw(tag);
use Lintian::Util qw(get_dsc_info get_deb_info);

use constant EMPTY => q{};
use constant COLON => q{:};
use constant SLASH => q{/};

use constant EVIL_CHARACTERS => qr,[/&|;\$"'<>],o;

use Moo::Role;
use namespace::clean;

=encoding utf-8

=head1 NAME

Lintian::Processable -- An (abstract) object that Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable;
 
 # Instantiate via Lintian::Processable
 my $proc = Lintian::Processable->new;
 $proc->init_from_file('lintian_2.5.0_all.deb');
 my $package = $proc->pkg_name;
 my $version = $proc->pkg_version;
 # etc.

=head1 DESCRIPTION

Instances of this perl class are objects that Lintian can process (e.g.
deb files).  Multiple objects can then be combined into
L<groups|Lintian::Processable::Group>, which Lintian will process
together.

=head1 INSTANCE METHODS

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

=item $proc->pkg_name

Returns the package name.

=item $proc->pkg_version

Returns the version of the package.

=item $proc->pkg_path

Returns the path to the packaged version of actual package.  This path
is used in case the data needs to be extracted from the package.

Note: This may return the path to a symlink to the package.

=item $proc->pkg_type

Returns the type of package (e.g. binary, source, udeb ...)

=item $proc->pkg_arch

Returns the architecture(s) of the package. May return multiple values
from changes processables.  For source processables it is "source".

=item $proc->pkg_src

Returns the name of the source package.

=item $proc->pkg_src_version

Returns the version of the source package.

=item $proc->tainted

Returns a truth value if one or more fields in this Processable is
tainted.  On a best effort basis tainted fields will be sanitized
to less dangerous (but possibly invalid) values.

=item $proc->identifier

Produces an identifier for this processable.  The identifier is
based on the type, name, version and architecture of the package.

=item lab

Returns a reference to lab this Processable is in.

=item base_dir

Returns the base directory of this package inside the lab.

=item group

Returns a reference to the Processable::Group related to this entry.

=cut

=item extra_fields

Returns a reference to the extra fields related to this entry.

=cut

=item link_label

Returns a reference to the extra fields related to this entry.

=cut

=item saved_link

Returns a reference to the extra fields related to this entry.

=cut

has name => (is => 'rw');
has type => (is => 'rw');

has verbatim => (is => 'rw', default => sub { {} });
has unfolded => (is => 'rwp', default => sub { {} });
has shared_storage => (is => 'rwp', default => sub { {} });

has pkg_name => (is => 'rw');
has pkg_version => (is => 'rw', default => EMPTY);
has pkg_src => (is => 'rw');
has pkg_arch => (is => 'rw', default => EMPTY);
has pkg_path => (is => 'rw');
has pkg_type => (is => 'rw');
has pkg_src_version => (is => 'rw', default => EMPTY);

has tainted => (is => 'rw', default => 0);

has identifier =>
  (is => 'rw', coerce => sub { my $id = shift; $id =~ s/\s+/_/g; $id; });
has lab => (is => 'rw');
has base_dir => (is => 'rw');
has group => (is => 'rw');

has extra_fields => (is => 'rw', default => sub { {} });

has link_label => (is => 'rw', default => EMPTY);
has saved_link => (is => 'rw', default => EMPTY);

=item info

Returns the L<info|Lintian::Collect> object associated with this entry.

Overrides info from L<Lintian::Processable>.

=cut

sub info {
    my ($self) = @_;

    return $self;
}

=item clear_cache

Clears any caches held; this includes discarding the L<info|Lintian::Collect> object.

Overrides clear_cache from L<Lintian::Processable>.

=cut

sub clear_cache {
    my ($self) = @_;

    $self->info({});
    return;
}

=item remove

Removes all unpacked parts of the package in the lab.  Returns a truth
value if successful.

=cut

sub remove {
    my ($self) = @_;

    $self->clear_cache;

    path($self->base_dir)->remove_tree
      if -e $self->base_dir;

    return;
}

=item get_group_id

Calculates an appropriate group id for the package. It is based
on the name and the version of the src-pkg.

=cut

sub get_group_id {
    my ($self) = @_;

    my $id = $self->pkg_src . SLASH . $self->pkg_src_version;

    return $id;
}

=item clean_field

Cleans a field of evil characters to prevent traversal or worse.

=cut

sub clean_field {
    my ($self, $field) = @_;

    my $clean = $self->$field;
    my $evil = 0 + ($clean =~ s,${\EVIL_CHARACTERS},_,g);

    $self->tainted(1)
      if $evil;

    $self->$field($clean);

    return;
}

=item link

Returns the link in the work area to the input data.

=cut

sub link {
    my ($self) = @_;

    unless (length $self->saved_link) {

        croak 'Please set base directory for processable first'
          unless length $self->base_dir;

        croak 'Please set link label for processable first'
          unless length $self->link_label;

        my $link = path($self->base_dir)->child($self->link_label)->stringify;
        $self->saved_link($link);
    }

    return $self->saved_link;
}

=item create

Creates a link to the input file near where all files in that
group will be unpacked and analyzed.

=cut

sub create {
    my ($self) = @_;

    return
      if -l $self->link;

    croak 'Please set base directory for processable first'
      unless length $self->base_dir;

    path($self->base_dir)->mkpath
      unless -e $self->base_dir;

    symlink($self->pkg_path, $self->link)
      or croak 'symlinking ' . $self->pkg_path . "failed: $!";

    return;
}

=item guess_name

Creates a link to the input file near where all files in that
group will be unpacked and analyzed.

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

Originally written by Niels Thykier <niels@thykier.net> for Lintian.
Substantial portions written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintian::Processable::Binary>

L<Lintian::Processable::Buildinfo>

L<Lintian::Processable::Changes>,

L<Lintian::Processable::Source>

L<Lintian::Processable::Udeb>

L<Lintian::Processable::Group>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
