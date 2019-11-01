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

use parent qw(Class::Accessor::Fast);

use strict;
use warnings;

use Carp qw(croak);
use Cwd qw(realpath);
use File::Spec;
use Path::Tiny;
use Scalar::Util qw(refaddr);

use Lintian::Collect;
use Lintian::Util qw(get_deb_info get_dsc_info strip);

=head1 NAME

Lintian::Processable -- An (abstract) object that Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable;
 
 # Instantiate via Lintian::Processable
 my $proc = Lintian::Processable->new;
 $proc->init_from_file('lintian_2.5.0_all.deb');
 my $pkg_name = $proc->pkg_name;
 my $pkg_version = $proc->pkg_version;
 # etc.

=head1 DESCRIPTION

Instances of this perl class are objects that Lintian can process (e.g.
deb files).  Multiple objects can then be combined into
L<groups|Lintian::Processable::Group>, which Lintian will process
together.

=head1 CLASS METHODS

=over 4

=item new (FILE[, TYPE])

Creates a processable from FILE.  If TYPE is given, the FILE is
assumed to be that TYPE otherwise the type is determined by the file
extension.

TYPE is one of "binary" (.deb), "udeb" (.udeb), "source" (.dsc) or
"changes" (.changes).

=cut

# Black listed characters - any match will be replaced with a _.
use constant EVIL_CHARACTERS => qr,[/&|;\$"'<>],o;

# internal initialization method.
#  reads values from fields etc.
sub new {
    my ($class, $file, $pkg_type) = @_;
    my $pkg_path;
    my $self;

    if (not defined $pkg_type) {
        if ($file =~ m/\.dsc$/o) {
            $pkg_type = 'source';
        } elsif ($file =~ m/\.buildinfo$/o) {
            $pkg_type = 'buildinfo';
        } elsif ($file =~ m/\.deb$/o) {
            $pkg_type = 'binary';
        } elsif ($file =~ m/\.udeb$/o) {
            $pkg_type = 'udeb';
        } elsif ($file =~ m/\.changes$/o) {
            $pkg_type = 'changes';
        } else {
            croak "$file is not a known type of package";
        }
    }

    croak "$file does not exists"
      unless -f $file;

    $pkg_path = realpath($file);
    croak "Cannot resolve $file: $!"
      unless $pkg_path;

    $self = {
        pkg_type => $pkg_type,
        pkg_path => $pkg_path,
        tainted => 0,
    };

    if ($pkg_type eq 'binary' or $pkg_type eq 'udeb'){
        my $dinfo = get_deb_info($pkg_path)
          or croak "could not read control data in $pkg_path: $!";
        my $pkg_name = $dinfo->{package};
        my $pkg_src = $dinfo->{source};
        my $pkg_version = $dinfo->{version};
        my $pkg_src_version = $pkg_version;

        unless ($pkg_name) {
            my $type = $pkg_type;
            $type = 'deb' if $type eq 'binary';
            $pkg_name = _derive_name($pkg_path, $type)
              or croak "Cannot determine the name of $pkg_path";
        }

        # Source may be left out if it is the same as $pkg_name
        $pkg_src = $pkg_name unless (defined $pkg_src && length $pkg_src);

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
        $self->{'extra-fields'} = $dinfo;
    } elsif ($pkg_type eq 'source'){
        my $dinfo = get_dsc_info($pkg_path)
          or croak "$pkg_path is not valid dsc file";
        my $pkg_name = $dinfo->{source} // '';
        my $pkg_version = $dinfo->{version};
        if ($pkg_name eq '') {
            croak "$pkg_path is missing Source field";
        }
        $self->{pkg_name} = $pkg_name;
        $self->{pkg_version} = $pkg_version;
        $self->{pkg_arch} = 'source';
        $self->{pkg_src} = $pkg_name; # it is own source pkg
        $self->{pkg_src_version} = $pkg_version;
        $self->{'extra-fields'} = $dinfo;
    } elsif ($pkg_type eq 'buildinfo' or $pkg_type eq 'changes'){
        my $cinfo = get_dsc_info($pkg_path)
          or croak "$pkg_path is not a valid $pkg_type file";
        my $pkg_version = $cinfo->{version};
        my $pkg_name = $cinfo->{source}//'';
        unless ($pkg_name) {
            $pkg_name = _derive_name($pkg_path, $pkg_type)
              or croak "Cannot determine the name of $pkg_path";
        }
        $self->{pkg_name} = $pkg_name;
        $self->{pkg_version} = $pkg_version;
        $self->{pkg_src} = $pkg_name;
        $self->{pkg_src_version} = $pkg_version;
        $self->{pkg_arch} = $cinfo->{architecture};
        $self->{'extra-fields'} = $cinfo;
    } else {
        croak "Unknown package type $pkg_type";
    }
    # make sure these are not undefined
    $self->{pkg_version}     = '' unless (defined $self->{pkg_version});
    $self->{pkg_src_version} = '' unless (defined $self->{pkg_src_version});
    $self->{pkg_arch}        = '' unless (defined $self->{pkg_arch});
    # make sure none of the fields can cause traversal.
    for my $field (qw(pkg_name pkg_version pkg_src pkg_src_version pkg_arch)) {
        if ($self->{$field} =~ m,${\EVIL_CHARACTERS},o){
            # None of these fields are allowed to contain a these
            # characters.  This package is most likely crafted to
            # cause Path traversals or other "fun" things.
            $self->{tainted} = 1;
            $self->{$field} =~ s,${\EVIL_CHARACTERS},_,go;
        }
    }
    bless $self, $class;
    $self->_make_identifier;
    return $self;
}

# _derive_name ($file, $ext)
#
# Derive the name from the file name
#  - the name is the part of the basename up to (and excl.) the first "_".
#
# _derive_name ('somewhere/lintian_2.5.2_amd64.changes', 'changes') eq 'lintian'
sub _derive_name {
    my ($file, $ext) = @_;
    my ($name) = ($file =~ m,(?:.*/)?([^_/]+)[^/]*\.$ext$,);
    return $name;
}

sub _new_from_proc {
    my ($type, $proc, $lab, $base_dir) = @_;
    my $self = {};
    bless $self, $type;
    $self->{pkg_name}        = $proc->pkg_name;
    $self->{pkg_version}     = $proc->pkg_version;
    $self->{pkg_type}        = $proc->pkg_type;
    $self->{pkg_src}         = $proc->pkg_src;
    $self->{pkg_src_version} = $proc->pkg_src_version;
    $self->{pkg_path}        = $proc->pkg_path;
    $self->{lab}             = $lab;
    $self->{info}            = undef; # load on demand.

    if ($self->pkg_type ne 'source') {
        $self->{pkg_arch} = $proc->pkg_arch;
    } else {
        $self->{pkg_arch} = 'source';
    }

    $self->{base_dir} = $base_dir;
    $self->_make_identifier;

    if ($proc->isa('Lintian::Processable')) {
        my $ctrl = $proc->_ctrl_fields;
        if ($ctrl) {
            # The processable has already loaded the fields, cache them to save
            # info from doing it later...
            $self->{info}
              = Lintian::Collect->new($self->pkg_name, $self->pkg_type,
                $self->base_dir, $ctrl);
        }
    }
    return $self;
}

=back

=head1 INSTANCE METHODS

=over 4

=cut

# $proc->_ctrl_fields
#
# Return a hashref of the control fields if available.  Used by
# L::Lab::Entry to avoid (re-)loading the fields from the control
# file.
sub _ctrl_fields {
    my ($self) = @_;
    return $self->{'extra-fields'} if exists $self->{'extra-fields'};
    return;
}

sub _make_identifier {
    my ($self) = @_;
    my $pkg_type = $self->pkg_type;
    my $pkg_name = $self->pkg_name;
    my $pkg_version = $self->pkg_version;
    my $pkg_arch = $self->pkg_arch;
    my $id = "$pkg_type:$pkg_name/$pkg_version";
    if ($pkg_type ne 'source') {
        $pkg_arch =~ s/\s++/_/g; # avoid spaces in ids
        $id .= "/$pkg_arch";
    }
    $self->{identifier} = $id;
    return;
}

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

=item base_dir

Returns the base directory of this package inside the lab.

=item lab

Returns a reference to the laboratory related to this entry.

=cut

Lintian::Processable->mk_ro_accessors(
    qw(pkg_name pkg_version pkg_src pkg_arch pkg_path pkg_type pkg_src_version tainted identifier lab base_dir)
);

=item $proc->group([$group])

Returns the L<group|Lintian::Processable::Group> $proc is in,
if any.  If the processable is not in a group, this returns C<undef>.

Can also be used to set the group of this processable.

=cut

Lintian::Processable->mk_accessors(qw(group));

=item from_lab (LAB)

Returns a truth value if this entry is from LAB.

=cut

sub from_lab {
    my ($self, $lab) = @_;
    return refaddr $lab eq (refaddr $self->{'lab'} // q{}) ? 1 : 0;
}

=item info

Returns the L<info|Lintian::Collect> object associated with this entry.

Overrides info from L<Lintian::Processable>.

=cut

sub info {
    my ($self) = @_;
    my $info;
    $info = $self->{info};
    if (!defined $info) {
        croak('Cannot load info, entry does not exist') unless $self->exists;

        $info = Lintian::Collect->new($self->pkg_name, $self->pkg_type,
            $self->base_dir);
        $self->{info} = $info;
    }
    return $info;
}

=item clear_cache

Clears any caches held; this includes discarding the L<info|Lintian::Collect> object.

Overrides clear_cache from L<Lintian::Processable>.

=cut

sub clear_cache {
    my ($self) = @_;
    delete $self->{info};
    return;
}

=item remove

Removes all unpacked parts of the package in the lab.  Returns a truth
value if successful.

=cut

sub remove {
    my ($self) = @_;
    my $basedir = $self->{base_dir};
    return 1 if(!-e $basedir);
    $self->clear_cache;
    path($basedir)->remove_tree
      if -d $basedir;
    return 1;
}

=item exists

Returns a truth value if the entry exists.

=cut

sub exists {
    my ($self) = @_;
    my $pkg_type = $self->{pkg_type};
    my $base_dir = $self->{base_dir};

    # Check if the relevant symlink exists.
    if ($pkg_type eq 'changes'){
        return 1 if -l "$base_dir/changes";
    } elsif ($pkg_type eq 'buildinfo') {
        return 1 if -l "$base_dir/buildinfo";
    } elsif ($pkg_type eq 'binary' or $pkg_type eq 'udeb') {
        return 1 if -l "$base_dir/deb";
    } elsif ($pkg_type eq 'source'){
        return 1 if -l "$base_dir/dsc";
    }

    # No unpack level and no symlink => the entry does not
    # exist or it is too broken in its current state.
    return 0;
}

=item create

Creates a minimum entry, in which collections and checks
can be run.  Note if it already exists, then this will do
nothing.

=cut

sub create {
    my ($self) = @_;
    my $pkg_type = $self->{pkg_type};
    my $base_dir = $self->{base_dir};
    my $pkg_path = $self->{pkg_path};
    my $lab      = $self->{lab};
    my $link;
    my $madedir = 0;

    if (not -d $base_dir) {
        # In the pool we may have to create multiple directories. On
        # error we only remove the "top dir" and that is enough.
        path($base_dir)->mkpath;
        $madedir = 1;
    } else {
        # If $base_dir exists, then check if the entry exists
        # - this is optimising for "non-existence" which is
        #   often the common case.
        return 0 if $self->exists;
    }
    if ($pkg_type eq 'changes'){
        $link = "$base_dir/changes";
    } elsif ($pkg_type eq 'buildinfo'){
        $link = "$base_dir/buildinfo";
    } elsif ($pkg_type eq 'binary' or $pkg_type eq 'udeb') {
        $link = "$base_dir/deb";
    } elsif ($pkg_type eq 'source'){
        $link = "$base_dir/dsc";
    } else {
        croak "create cannot handle $pkg_type";
    }
    unless (symlink($pkg_path, $link)){
        my $err = $!;
        # "undo" the mkdir if the symlink fails.
        rmdir $base_dir  if $madedir;
        $! = $err;
        croak "symlinking $pkg_path failed: $!";
    }
    if ($pkg_type eq 'source'){
        # If it is a source package, pull in all the related files
        #  - else unpacked will fail or we would need a separate
        #    collection for the symlinking.
        my (undef, $dir, undef) = File::Spec->splitpath($pkg_path);
        for my $fs (split(m/\n/o, $self->info->field('files'))) {
            strip($fs);
            next if $fs eq '';
            my @t = split(/\s+/o,$fs);
            next if ($t[2] =~ m,/,o);
            symlink("$dir/$t[2]", "$base_dir/$t[2]")
              or croak("cannot symlink file $t[2]: $!");
        }
    }
    return 1;
}

=item $proc->get_field ($field[, $def])

Optional method to access a field in the underlying data set.

Returns $def if the field is not present or the implementation does
not have (or want to expose) it.  This method is I<not> guaranteed to
return the same value as "$proc->info->field ($field, $def)".

If C<$def> is omitted is defaults to C<undef>.

Default implementation accesses them via the hashref stored in
"extra-fields" if present.  If the field is present, but not defined
$def is returned instead.

NB: This is mostly an optimization used by L<Lintian::Lab> to avoid
(re-)reading the underlying package data.

=cut

sub get_field {
    my ($self, $field, $def) = @_;
    return $def
      unless exists $self->{'extra-fields'}
      and exists $self->{'extra-fields'}{$field};
    return $self->{'extra-fields'}{$field}//$def;
}

=item get_group_id

Calculates an appropriate group id for the package. It is based
on the name and the version of the src-pkg.

=cut

sub get_group_id{
    my ($self) = @_;

    my $id = $self->pkg_src . '/' . $self->pkg_src_version;

    return $id;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintian::Processable::Group>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
