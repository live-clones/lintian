package Lintian::Lab::Util;

use strict;
use warnings;

use Carp qw(croak);

use Lintian::Lab::Manifest;
use Util ();

# local_mirror_manifests ($mirdir, $dists, $areas, $archs)
#
# Returns a list of manifests that represents what is on the local mirror
# at $mirdir.  3 manifests will be returned, one for "source", one for "binary"
# and one for "udeb" packages.  They are populated based on the "Sources" and
# "Packages" files.
#
# $mirdir - the path to the local mirror
# $dists  - listref of dists to consider (i.e. ['unstable'])
# $areas  - listref of areas to consider (i.e. ['main', 'contrib', 'non-free'])
# $archs  - listref of archs to consider (i.e. ['i386', 'amd64'])
#
sub local_mirror_manifests {
    my ($mirdir, $dists, $areas, $archs) = @_;
    my $srcman = Lintian::Lab::Manifest->new ('source');
    my $binman = Lintian::Lab::Manifest->new ('binary');
    my $udebman = Lintian::Lab::Manifest->new ('udeb');
    foreach my $dist (@$dists) {
        foreach my $area (@$areas) {
            my $srcs = "$mirdir/dists/$dist/$area/source/Sources";
            my $srcfd = _open_data_file ($srcs);
            my $srcsub = sub { _parse_srcs_pg ($srcman, $mirdir, $area, @_) };
            # Binaries have a "per arch" file.
            foreach my $arch (@$archs) {
                my $pkgs = "$mirdir/dists/$dist/$area/binary-$arch/Packages";
                my $upkgs = "$mirdir/dists/$dist/$area/debian-installer/" .
                    "binary-$arch/Packages";
                my $pkgfd = _open_data_file ($pkgs);
                my $binsub = sub { _parse_pkgs_pg ($binman, $mirdir, $area, @_) };
                my $upkgfd = _open_data_file ($upkgs);
                my $udebsub = sub { _parse_pkgs_pg ($udebman, $mirdir, $area, @_) };
                Util::_parse_dpkg_control_iterative ($binsub, $pkgfd);
                Util::_parse_dpkg_control_iterative ($udebsub, $upkgfd);
                close $pkgfd;
                close $upkgfd;
            }
        }
    }
    return ($srcman, $binman, $udebman);
}

# _open_data_file ($file)
#
# Opens $file if it exists, otherwise it tries common extensions (i.e. .gz) and opens
# that instead.  It may pipe the file through a external decompressor, so the returned
# file descriptor cannot be assumed to be a file.
#
# If $file does not exists and no common extensions are found, this croaks.
sub _open_data_file {
    my ($file) = @_;
    if (-e $file) {
        open my $fd, '<', $file or croak "opening $file: $!";
        return $fd;
    }
    foreach my $com (['gz', ['gzip', '-dc']] ){
        my ($ext, $cmd) = @$com;
        if ( -e "$file.$ext") {
            open my $c, '-|', @$cmd, "$file.$ext" or croak "running @$cmd $file.$ext";
            return $c;
        }
    }
    croak "Cannot find $file";
}

# Helper for local_mirror_manifests - it parses a paragraph from Packages file
sub _parse_pkgs_pg {
    my ($manifest, $mirdir, $area, $data) = @_;
    unless ($data->{'source'}) {
        $data->{'source'} = $data->{'package'};
    } elsif ($data->{'source'} =~ /^([-+\.\w]+)\s+\((.+)\)$/) {
        $data->{'source'} = $1;
        $data->{'source-version'} = $2;
    } else {
        $data->{'source-version'} = $data->{'version'};
    }
    unless (defined $data->{'source-version'}) {
        $data->{'source-version'} = $data->{'version'};
    }
    $data->{'file'} = $mirdir . '/' . $data->{'filename'};
    $data->{'area'} = $area;
    # $manifest strips redundant fields for us.  But for clarity and to
    # avoid "hard to debug" cases $manifest renames the fields, we explicitly
    # remove the "filename" field.
    delete $data->{'filename'};

    $manifest->set ($data);
}

# Helper for local_mirror_manifests - it parses a paragraph from Sources file
sub _parse_srcs_pg {
    my ($manifest, $mirdir, $area, $data) = @_;
    my $dir = $data->{'directory'}//'';
    $dir .= '/' if $dir;
    foreach my $f (split m/\n/, $data->{'files'}) {
        $f =~ s/^\s++//o;
        next unless $f && $f =~ m/\.dsc$/;
        my (undef, undef, $file) = split m/\s++/, $f;
        # $dir should end with a slash if it is non-empty.
        $data->{'file'} = $mirdir . "/$dir" . $file;
        last;
    }
    $data->{'area'} = $area;
    # Rename a field :)
    $data->{'source'} = $data->{'package'};

    # $manifest strips redundant fields for us.
    $manifest->set ($data);
}

1;

