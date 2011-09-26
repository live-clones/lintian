# Lab -- Perl laboratory functions for lintian

# Copyright (C) 1998-2004 Various authors
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

package Lab;

use strict;
use warnings;
use base qw(Exporter);

# Lab format Version Number increased whenever incompatible changes
# are done to the lab so that all packages are re-unpacked
use constant LAB_FORMAT => 10;

# Export now due to cicular depends between Lab and Lab::Package.
our (@EXPORT, @EXPORT_OK, %EXPORT_TAGS);

BEGIN {
    @EXPORT = ();
    %EXPORT_TAGS = (
        constants => [qw(LAB_FORMAT)],
        );
    @EXPORT_OK = (
        @{$EXPORT_TAGS{constants}}
        );
};

use Util;
# Only used by _populate_with_dist; remove when not needed
use Lintian::Output qw(:messages);
use Lintian::Command qw(spawn);
use Lab::Package;

use Cwd;
use File::Temp;



# Quiet "Name "main::LINTIAN_ROOT" used only once"
# only used by _populate_with_dist
() = ($main::LINTIAN_ROOT);

my $LINTIAN_ROOT = $main::LINTIAN_ROOT;

sub new {
    my ( $class, $dir ) = @_;

    my $self = {};
    bless $self, $class;

    $self->_init( $dir );
    return $self;
}

# returns a truth value if the lab is initialized and exists
sub is_lab {
    my ( $self ) = @_;

    return unless $self->{dir};
    return -d "$self->{dir}/binary"
        && -d "$self->{dir}/udeb"
        && -d "$self->{dir}/source"
        && -d "$self->{dir}/info";
}

sub _init {
    my ( $self, $dir ) = @_;

    if ( $dir ) {
        # Make sure we can always find it, even if we chdir around a lot.
        my $absdir = Cwd::realpath($dir);
        fail("Cannot determine the absolute path of $dir: $!") unless($absdir);
        $self->{mode} = 'static';
        $self->{dir} = $absdir;

        # This code is here fore BACKWARDS COMPATABILITY!
        #  - we can kill it when LAB_FORMAT goes from 10 to 11.
        #  Basically this auto-upgrades existing static labs to support changes files
        if (-d "$absdir" && ! -d "$absdir/changes") {
            mkdir("$absdir/changes", 0777)
                or fail("cannot create lab directory $absdir/changes");
        }
    } else {
        $self->{mode} = 'temporary';

        my $created = 0;
        for (1..10) {
            my $absdir;
            $dir = tmpnam(); # Not always absolute (e.g. if TMPDIR is relative)
            $absdir = Cwd::realpath($dir);
            fail("Cannot determine the absolute path of $dir: $!")
                unless $absdir;
            if ($self->_do_setup( $absdir )) {
                $created = 1;
                last;
            }
        }
        unless ($created) {
            fail("cannot create lab directory $dir");
        }
    }

    return 1;
}

# Initialization method for static labs; must be called after new.
sub setup_static {
    my ( $self ) = @_;

    unless ( $self->{mode} eq 'static' and $self->{dir} ) {
        warning('no laboratory specified (need to define LINTIAN_LAB)');
        return 0;
    }

    return $self->_do_setup( $self->{dir} );
}

# backing sub for setup_static and (in some cases) _init
sub _do_setup {
    my ( $self, $dir ) = @_;

    return unless $dir;

    v_msg("Setting up lab in $dir ...");

    # create lab directory
    # (Note, that the mode 0777 is reduced by the current umask.)
    unless (-d $dir && ( $self->{mode} eq 'static' )) {
        mkdir($dir,0777) or return 0;
    }

    # create base directories
    for my $subdir (qw( binary source udeb changes info )) {
        my $fulldir = "$dir/$subdir";
        if (not -d $fulldir) {
            mkdir($fulldir, 0777)
                or fail("cannot create lab directory $fulldir");
        }
    }

    # Just create empty files if they don't already exist.  If they do already
    # exist, we need to keep the old files so that the list-* unpack programs
    # can analyze what changed.
    for my $pkgtype (qw( binary source udeb )) {
        if (not -f "$dir/info/$pkgtype-packages") {
            touch_file("$dir/info/$pkgtype-packages")
                or fail("cannot create $pkgtype package list");
        }
    }

    $self->{dir} = $dir;
    $ENV{'LINTIAN_LAB'} = $dir;
    $self->_populate_with_dist();

    return 1;
}

# Deprecated; we need a better API for keeping the Lab in sync with a mirror.
sub _populate_with_dist {
    my ( $self ) = @_;

    return 0 unless $ENV{'LINTIAN_DIST'};
    return 0 unless $self->{dir};

    debug_msg(2, "spawning list-binpkg and list-srcpkg since LINTIAN_DIST=$ENV{'LINTIAN_DIST'}");

    my $v = $Lintian::Output::GLOBAL->verbosity_level() > 0 ? '-v' : '';
    my %opts = ( out => $Lintian::Output::GLOBAL->stdout );
    spawn(\%opts, ["$LINTIAN_ROOT/unpack/list-binpkg",
                  "$self->{dir}/info/binary-packages", $v])
        or fail('cannot create binary package list');
    spawn(\%opts, ["$LINTIAN_ROOT/unpack/list-srcpkg",
                  "$self->{dir}/info/source-packages", $v])
        or fail('cannot create source package list');
    spawn(\%opts, ["$LINTIAN_ROOT/unpack/list-binpkg",
                  "$self->{dir}/info/udeb-packages", '-u', $v])
        or fail('cannot create udeb package list');

    return 1;
}

# Deletes the lab if (and only if) it exists and is a static lab
# Returns a truth value on success
sub delete_static {
    my ( $self ) = @_;

    unless ( $self->{mode} eq 'static' and $self->{dir} ) {
        warning('no laboratory specified (need to define LINTIAN_LAB)');
        return 0;
    }

    return $self->_do_delete;
}

# Deletes the lab if (and only if) it is a temporary lab
# Returns a truth value on success (or it is not a temp lab)
sub delete {
    my ( $self ) = @_;

    return 1 unless $self->{mode} eq 'temporary';

    return $self->_do_delete;
}

# The backing sub for delete and delete_static
sub _do_delete {
    my ( $self ) = @_;

    return 0 unless $self->{dir};

    v_msg("Removing $self->{dir} ...");

    # chdir to root (otherwise, the shell will complain if we happen
    # to sit in the directory we want to delete :)
    chdir('/');

    # does the lab exist?
    unless (-d $self->{dir}) {
        # no.
        warning("cannot remove lab in directory $self->{dir} ! (directory does not exist)");
        return 0;
    }

    # sanity check if $self->{dir} really points to a lab :)
    unless (-d "$self->{dir}/binary") {
        # binary/ subdirectory does not exist--empty directory?
        my @t = glob("$self->{dir}/*");
        if ($#t+1 <= 2) {
            # yes, empty directory--skip it
            return 1;
        } else {
            # non-empty directory that does not look like a lintian lab!
            warning("directory $self->{dir} does not look like a lab! (please remove it yourself)");
            return 0;
        }
    }

    # looks ok.
    unless (delete_dir("$self->{dir}/binary",
                       "$self->{dir}/source",
                       "$self->{dir}/udeb",
                       "$self->{dir}/changes",
                       "$self->{dir}/info")) {
        warning("cannot remove lab directory $self->{dir} (please remove it yourself)");
    }

    # dynamic lab?
    if ($self->{mode} eq 'temporary') {
        if (rmdir($self->{dir}) != 1) {
            warning("cannot remove lab directory $self->{dir} (please remove it yourself)");
        }
    }

    $self->{dir} = '';

    return 1;
}


{

    # private helper variable.
    my %pkg_types = (
        'b' => 'binary',
        'binary' => 'binary',
        'c' => 'changes',
        'changes' => 'changes',
        's' => 'source',
        'source' => 'source',
        'u' => 'udeb',
        'udeb' => 'udeb',
    );

    sub get_lab_package {
        my ($self, $pkg_name, $pkg_version, $pkg_arch, $pkg_type, $pkg_path) = @_;
        my $vpkg_type = $pkg_types{$pkg_type};
        my $realpath = Cwd::realpath($pkg_path);
        my $dir;
        fail("Unknown package type $pkg_type") unless($vpkg_type);
        fail("Could not resolve the path of $pkg_path") unless($realpath);
        $dir = $self->{dir} . '/' . $vpkg_type . '/' . $pkg_name;
        $dir .= '/' . $pkg_version if $self->_supports_multiple_versions();
        $dir .= '/' . $pkg_arch if $self->_supports_multiple_architectures();
        return Lab::Package->new ($self, $pkg_name, $pkg_version, $vpkg_type,
                                  $realpath, $dir);

    }
}

# Returns a truth value if this is a "multi-version" Lab
# This means that a new version of the same package can be extracted to the lab
# without overwriting the old one.
sub _supports_multiple_versions{
    my ($self) = @_;
    return $self->{mode} eq 'temporary';
}

# Returns a truth value if this is a "multi-arch" Lab
# This means that (e.g.) an i386 and amd64 package with the same name will be stored
# separatedly.  Otherwise unpacking a new package with different architecture will
# override the old one.
sub _supports_multiple_architectures{
    my ($self) = @_;
    return $self->{mode} eq 'temporary';
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
