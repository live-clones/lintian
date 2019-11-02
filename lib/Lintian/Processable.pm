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

package Lintian::Processable;

use strict;
use warnings;

use Moo;

use Carp qw(croak);
use File::Spec;
use Path::Tiny;

use Lintian::Collect;
use Lintian::Util qw(get_deb_info get_dsc_info strip);

use constant EMPTY => q{};
use constant COLON => q{:};
use constant SLASH => q{/};

use constant EVIL_CHARACTERS => qr,[/&|;\$"'<>],o;

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

=item saved_info

Returns a reference to the info structure related to this entry.

=cut

has pkg_name => (is => 'rw');
has pkg_version => (is => 'rw', default => EMPTY);
has pkg_src => (is => 'rw');
has pkg_arch => (is => 'rw', default => EMPTY);
has pkg_path => (is => 'rw');
has pkg_type => (is => 'rw');
has pkg_src_version => (is => 'rw', default => EMPTY);
has tainted => (is => 'rw', default => 0);
has identifier => (is => 'rw');
has lab => (is => 'rw');
has base_dir => (is => 'rw');
has group => (is => 'rw');
has saved_info => (is => 'rw');

=item init (FILE[, TYPE])

Creates a processable from FILE.  If TYPE is given, the FILE is
assumed to be that TYPE otherwise the type is determined by the file
extension.

TYPE is one of "binary" (.deb), "udeb" (.udeb), "source" (.dsc) or
"changes" (.changes).

=cut

sub init {
    my ($self, $file, $type) = @_;

    my $pkg_path = path($file)->realpath->stringify;
    $self->pkg_path($pkg_path);
    croak "Cannot resolve $file: $!"
      unless $pkg_path;

    croak 'File ' . $self->pkg_path . "$file does not exist"
      unless -f $self->pkg_path;

    unless (defined $type) {

        if ($file =~ m/\.dsc$/o) {
            $type = 'source';

        } elsif ($file =~ m/\.buildinfo$/o) {
            $type = 'buildinfo';

        } elsif ($file =~ m/\.deb$/o) {
            $type = 'binary';

        } elsif ($file =~ m/\.udeb$/o) {
            $type = 'udeb';

        } elsif ($file =~ m/\.changes$/o) {
            $type = 'changes';

        } else {
            croak "$file is not a known type of package";
        }
    }

    $self->pkg_type($type);

    if ($type eq 'binary' or $type eq 'udeb'){
        my $dinfo = get_deb_info($pkg_path)
          or croak "could not read control data in $pkg_path: $!";
        my $package = $dinfo->{package};
        my $source = $dinfo->{source};
        my $version = $dinfo->{version};
        my $source_version = $version;

        unless ($package) {
            my $type = $type;
            $type = 'deb' if $type eq 'binary';
            $package = _derive_name($pkg_path, $type)
              or croak "Cannot determine the name of $pkg_path";
        }

        # Source may be left out if it is the same as $package
        $source = $package unless (defined $source && length $source);

        # Source may contain the version (in parentheses)
        if ($source =~ m/(\S++)\s*\(([^\)]+)\)/o){
            $source = $1;
            $source_version = $2;
        }
        $self->pkg_name($package);
        $self->pkg_version($version // EMPTY);
        $self->pkg_arch($dinfo->{architecture} // EMPTY);
        $self->pkg_src($source);
        $self->pkg_src_version($source_version // EMPTY);
        $self->{'extra-fields'} = $dinfo;

    } elsif ($type eq 'source'){
        my $dinfo = get_dsc_info($pkg_path)
          or croak "$pkg_path is not valid dsc file";
        my $package = $dinfo->{source} // '';
        my $version = $dinfo->{version};
        if ($package eq '') {
            croak "$pkg_path is missing Source field";
        }
        $self->pkg_name($package);
        $self->pkg_version($version // EMPTY);
        $self->pkg_arch('source');
        $self->pkg_src($package); # it is own source pkg
        $self->pkg_src_version($version // EMPTY);
        $self->{'extra-fields'} = $dinfo;

    } elsif ($type eq 'buildinfo' or $type eq 'changes'){
        my $cinfo = get_dsc_info($pkg_path)
          or croak "$pkg_path is not a valid $type file";
        my $version = $cinfo->{version};
        my $package = $cinfo->{source}//'';
        unless ($package) {
            $package = _derive_name($pkg_path, $type)
              or croak "Cannot determine the name of $pkg_path";
        }
        $self->pkg_name($package);
        $self->pkg_version($version // EMPTY);
        $self->pkg_src($package);
        $self->pkg_src_version($version // EMPTY);
        $self->pkg_arch($cinfo->{architecture} // EMPTY);
        $self->{'extra-fields'} = $cinfo;

    } else {
        croak "Unknown package type $type";
    }

    # make sure none of the fields can cause traversal.
    for my $field (qw(pkg_name pkg_version pkg_src pkg_src_version pkg_arch)) {
        if ($self->$field =~ m,${\EVIL_CHARACTERS},o){
            # None of these fields are allowed to contain a these
            # characters.  This package is most likely crafted to
            # cause Path traversals or other "fun" things.
            $self->tainted(1);
            my $clean = $self->$field;
            $clean =~ s,${\EVIL_CHARACTERS},_,go;
            $self->$field($clean);
        }
    }

    my $id
      = $self->pkg_type . COLON . $self->pkg_name . SLASH . $self->pkg_version;

    $id .= SLASH . $self->pkg_arch
      unless $self->pkg_type eq 'source';

    # avoid spaces in identifiers
    $id =~ s/\s++/_/g;

    $self->identifier($id);

    return;
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

=item info

Returns the L<info|Lintian::Collect> object associated with this entry.

Overrides info from L<Lintian::Processable>.

=cut

sub info {
    my ($self) = @_;

    if (!defined $self->saved_info) {

        croak('Cannot load info, entry does not exist')
          unless $self->exists;

        my $info = Lintian::Collect->new(
            $self->pkg_name, $self->pkg_type,
            $self->base_dir, $self->{'extra-fields'});

        $self->saved_info($info);
    }

    return $self->saved_info;
}

=item clear_cache

Clears any caches held; this includes discarding the L<info|Lintian::Collect> object.

Overrides clear_cache from L<Lintian::Processable>.

=cut

sub clear_cache {
    my ($self) = @_;

    $self->info(undef);
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

=item exists

Returns a truth value if the entry exists.

=cut

sub exists {
    my ($self) = @_;
    my $type = $self->pkg_type;
    my $base_dir = $self->base_dir;

    return 0
      unless defined $base_dir;

    # Check if the relevant symlink exists.
    if ($type eq 'changes'){
        return 1 if -l "$base_dir/changes";
    } elsif ($type eq 'buildinfo') {
        return 1 if -l "$base_dir/buildinfo";
    } elsif ($type eq 'binary' or $type eq 'udeb') {
        return 1 if -l "$base_dir/deb";
    } elsif ($type eq 'source'){
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
    my $type = $self->pkg_type;
    my $base_dir = $self->base_dir;
    my $pkg_path = $self->pkg_path;
    my $lab      = $self->lab;
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
    if ($type eq 'changes'){
        $link = "$base_dir/changes";
    } elsif ($type eq 'buildinfo'){
        $link = "$base_dir/buildinfo";
    } elsif ($type eq 'binary' or $type eq 'udeb') {
        $link = "$base_dir/deb";
    } elsif ($type eq 'source'){
        $link = "$base_dir/dsc";
    } else {
        croak "create cannot handle $type";
    }
    unless (symlink($pkg_path, $link)){
        my $err = $!;
        # "undo" the mkdir if the symlink fails.
        rmdir $base_dir  if $madedir;
        $! = $err;
        croak "symlinking $pkg_path failed: $!";
    }
    if ($type eq 'source'){
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
