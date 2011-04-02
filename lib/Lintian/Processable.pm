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

use Util;

# Black listed characters - any match will be replaced with a _.
use constant EVIL_CHARACTERS => qr,[/&|;\$"'<>],o;

=head1 NAME

Lintian::Processable -- An object that Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable;

 my $proc = Lintian::Processable->new('binary', 'lintian_2.5.0_all.deb');
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
    my ($class, $pkg_type, $pkg_path) = @_;
    my $self = {};
    bless $self, $class;
    $self->{pkg_type} = $pkg_type;
    $self->{pkg_path} = $pkg_path;
    $self->{tainted} = 0;
    $self->_init ($pkg_type, $pkg_path);
    return $self;
}

=pod


=item $proc->pkg_name()

Returns the package name.

=item $proc->pkg_version()

Returns the version of the package.

=item $proc->pkg_path()

Returns the path to the packaged version of actual package.  This path
is used in case the data needs to be extracted from the package.

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

Lintian::Processable->mk_ro_accessors (qw(pkg_name pkg_version pkg_src pkg_arch pkg_path pkg_type pkg_src_version group tainted));

=item $proc->info()

Returns L<Lintian::Collect|$info> element for this processable.

=cut

sub info{
    my ($self) = @_;
    my $info = $self->{info};
    if (! defined $info) {
        # load only if we need it
        require Lintian::Collect;
        my $info = Lintian::Collect->new($self->pkg_name(), $self->pkg_type());
        $self->{info} = $info;
    }
    return $info;
}

=item $proc->lab_pkg([$lpkg])

Returns or sets the L<Lab::Package|$info> element for this processable.

=cut

Lintian::Processable->mk_accessors (qw(lab_pkg));

=item $proc->set_group($group)

Sets the L<Lintain::ProcessableGroup|group> of $proc.

=cut

sub set_group{
    my ($self, $group) = @_;
    $self->{group} = $group;
    return 1;
}

# internal initialization method.
#  reads values from fields etc.
sub _init{
    my ($self, $pkg_type, $pkg_path) = @_;
    if ($pkg_type eq 'binary' or $pkg_type eq 'udeb'){
        my $dinfo = get_deb_info ($pkg_path) or
            fail "could not read control data in $pkg_path: $!";
        my $pkg_name = $dinfo->{package} or
            fail "$pkg_path ($pkg_type) is missing mandatory \"Package\" field";
        my $pkg_src = $dinfo->{source};
        my $pkg_version = $dinfo->{version};
        my $pkg_src_version = $pkg_version;
        # Source may be left out if it is the same as $pkg_name
        $pkg_src = $pkg_name unless ( defined $pkg_src && length $pkg_src );

        # Source may contain the version (in parentheses)
        if ($pkg_src =~ m/(\S++)\s*\(([^\)]+)\)/o){
            $pkg_src = $1;
            $pkg_src_version = $2;
        }
        $self->{pkg_name} = $pkg_name;
        $self->{pkg_version} = $pkg_version;
        $self->{pkg_arch} = $dinfo->{architecture};
        $self->{pkg_src} = $pkg_src;
        $self->{pkg_src_version} = $pkg_src_version;
    } elsif ($pkg_type eq 'source'){
        my $dinfo = get_dsc_info ($pkg_path) or fail "$pkg_path is not valid dsc file";
        my $pkg_name = $dinfo->{source} or fail "$pkg_path is missing or has empty source field";
        my $pkg_version = $dinfo->{version};
        $self->{pkg_name} = $pkg_name;
        $self->{pkg_version} = $pkg_version;
        $self->{pkg_arch} = 'source';
        $self->{pkg_src} = $pkg_name; # it is own source pkg
        $self->{pkg_src_version} = $pkg_version;
    } elsif ($pkg_type eq 'changes'){
        my $cinfo = get_dsc_info ($pkg_path) or fail "$pkg_path is not a valid changes file";
        my ($pkg_name) = ($pkg_path =~ m,.*/([^/]+)\.changes,);
        my $pkg_version = $cinfo->{version};
        $self->{pkg_name} = $pkg_name;
        $self->{pkg_version} = $pkg_version;
        $self->{pkg_src} = $cinfo->{source}//$pkg_name;
        $self->{pkg_src_version} = $pkg_version;
        $self->{pkg_arch} = $cinfo->{architecture};
    } else {
        fail "Unknown package type $pkg_type";
    }
    # make sure these are not undefined
    $self->{pkg_version}     = '' unless (defined $self->{pkg_version});
    $self->{pkg_src_version} = '' unless (defined $self->{pkg_src_version});
    $self->{pkg_arch}        = '' unless (defined $self->{pkg_arch});
    # make sure none of the fields can cause traversal.
    foreach my $field (qw(pkg_name pkg_version pkg_src pkg_src_version pkg_arch)) {
        if ($self->{$field} =~ m,${\EVIL_CHARACTERS},o){
            # None of these fields are allowed to contain a these
            # characters.  This package is most likely crafted to
            # cause Path traversals or other "fun" things.
            $self->{tainted} = 1;
            $self->{$field} =~ s,${\EVIL_CHARACTERS},_,go;
        }
    }
    return 1;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintain::ProcessableGroup>

=cut

1;
