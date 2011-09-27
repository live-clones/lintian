# Copyright (C) 2011 Niels Thykier <niels@thykier.net>
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

## Represents something Lintian can process (e.g. a deb, dsc or a changes)
package Lintian::Processable;

use base qw(Class::Accessor);

use strict;
use warnings;

use Carp qw(croak);

use Util;

# Black listed characters - any match will be replaced with a _.
use constant EVIL_CHARACTERS => qr,[/&|;\$"'<>],o;

=head1 NAME

Lintian::Processable -- An (abstract) object that Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable;
 
 # Instantiate via Lintian::Processable::Package
 my $proc = Lintian::Processable::Package->new('binary', 'lintian_2.5.0_all.deb');
 my $pkg_name = $proc->pkg_name();
 my $pkg_version = $proc->pkg_version();
 # etc.

=head1 DESCRIPTION

Instances of this perl class are objects that Lintian can process (e.g.
deb files).  Multiple objects can then be combined into
L<Lintain::ProcessableGroup|groups>, which Lintian will process
together.

=head1 METHODS

=over 4

=item Lintian::Processable->new($pkg_type, $pkg_path)

Creates a new processable of type $pkg_type, which must be one of:
 'binary', 'udeb', 'source' or 'changes'

$pkg_path should be the absolute path to the package file that
defines this type of processable (e.g. the changes file).

=cut

sub new {
    my ($class, $pkg_type, @args) = @_;
    my $self = {};
    bless $self, $class;
    $self->{pkg_type} = $pkg_type;
    $self->{tainted} = 0;
    $self->_init ($pkg_type, @args);
    return $self;
}


=item $proc->pkg_name()

Returns the package name.

=item $proc->pkg_version()

Returns the version of the package.

=item $proc->pkg_path()

Returns the path to the packaged version of actual package.  This path
is used in case the data needs to be extracted from the package.

Note: This may return the path to a symlink to the package.

=item $proc->pkg_type()

Returns the type of package (e.g. binary, source, udeb ...)

=item $proc->pkg_arch()

Returns the architecture(s) of the package. May return multiple values
from source and changes processables.

=item $proc->pkg_src()

Returns the name of the source package.

=item $proc->pkg_src_version()

Returns the version of the source package.

=item $proc->group()

Returns the L<Lintain::ProcessableGroup|group> $proc is in,
if any.  If the processable is not in a group, this returns C<undef>.

=item $proc->tainted()

Returns a truth value if one or more fields in this Processable is
tainted.  On a best effort basis tainted fields will be sanitized
to less dangerous (but possibly invalid) values.

=cut

Lintian::Processable->mk_ro_accessors (qw(pkg_name pkg_version pkg_src pkg_arch pkg_path pkg_type pkg_src_version tainted));

=item $proc->info()

Returns L<Lintian::Collect|$info> element for this processable.

=cut

sub info {
    my ($self) = @_;
    my $info = $self->{info};
    if (! defined $info) {
        my $lpkg = $self->lab_pkg();
        fail "Need a Lab package before creating a Lintian::Collect\n"
            unless defined $lpkg;
        return $lpkg->info;
    }
    return $info;
}

=item $proc->clear_cache()

Discard the info element, so the memory used by it can be reclaimed.
Mostly useful when checking a lot of packages (e.g. on lintian.d.o).

=cut

sub clear_cache {
    my ($self) = @_;
    my $lpkg = $self->lab_pkg;
    $lpkg->clear_cache if defined $lpkg;
}

sub _init {
    my ($self, $pkg_type, @args) = @_;
    my $type = ref $self;
    if ($type && $type eq 'Lintian::Processable') {
        croak 'Cannot create Lintian::Processable directly';
    } elsif ($type) {
        croak "$type has not overridden " . ${type} . '::_init';
    }
    croak 'Lintian::Processable::_init should not be called directly';
}


=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintain::ProcessableGroup>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
