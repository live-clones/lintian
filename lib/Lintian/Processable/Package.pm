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
package Lintian::Processable::Package;

use base qw(Lintian::Processable Class::Accessor);

use strict;
use warnings;

use Carp qw(croak);

use Util qw(get_deb_info get_dsc_info);

# Black listed characters - any match will be replaced with a _.
use constant EVIL_CHARACTERS => qr,[/&|;\$"'<>],o;

=head1 NAME

Lintian::Processable::Package -- An object that Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable;
 
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

=item Lintian::Processable::Package->new($pkg_type, $pkg_path)

Creates a new processable of type $pkg_type, which must be one of:
 'binary', 'udeb', 'source' or 'changes'

$pkg_path should be the absolute path to the package file that
defines this type of processable (e.g. the changes file).

=item $proc->group([$group])

Returns the L<Lintain::ProcessableGroup|group> $proc is in,
if any.  If the processable is not in a group, this returns C<undef>.

Can also be used to set the group of this processable.

=item $proc->lab_pkg([$lpkg])

Returns or sets the L<Lab::Package|$info> element for this processable.

=cut

Lintian::Processable::Package->mk_accessors (qw(group lab_pkg));

# internal initialization method.
#  reads values from fields etc.
sub _init {
    my ($self, $pkg_type, $pkg_path) = @_;

    $self->{pkg_path} = $pkg_path;

    if ($pkg_type eq 'binary' or $pkg_type eq 'udeb'){
        my $dinfo = get_deb_info ($pkg_path) or
            croak "could not read control data in $pkg_path: $!";
        my $pkg_name = $dinfo->{package} or
            croak "$pkg_path ($pkg_type) is missing mandatory \"Package\" field";
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
        my $dinfo = get_dsc_info ($pkg_path) or croak "$pkg_path is not valid dsc file";
        my $pkg_name = $dinfo->{source} or croak "$pkg_path is missing or has empty source field";
        my $pkg_version = $dinfo->{version};
        $self->{pkg_name} = $pkg_name;
        $self->{pkg_version} = $pkg_version;
        $self->{pkg_arch} = 'source';
        $self->{pkg_src} = $pkg_name; # it is own source pkg
        $self->{pkg_src_version} = $pkg_version;
    } elsif ($pkg_type eq 'changes'){
        my $cinfo = get_dsc_info ($pkg_path) or croak "$pkg_path is not a valid changes file";
        my $pkg_version = $cinfo->{version};
        my $pkg_name = $cinfo->{source}//'';
        unless ($pkg_name) {
            # No source field? Derive the name from the file name
            # lintian_2.5.2_amd64.changes => $pkg_name = 'lintian'
            ($pkg_name) = ($pkg_path =~ m,.*/([^_/]+)[^/]*+\.changes$,);
        }
        $self->{pkg_name} = $pkg_name;
        $self->{pkg_version} = $pkg_version;
        $self->{pkg_src} = $pkg_name;
        $self->{pkg_src_version} = $pkg_version;
        $self->{pkg_arch} = $cinfo->{architecture};
    } else {
        croak "Unknown package type $pkg_type";
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

L<Lintian::Processable>

L<Lintain::ProcessableGroup>

=cut

1;
